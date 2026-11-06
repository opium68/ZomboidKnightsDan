using System;
using System.IO;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;

public sealed class PzBackupFile {
 public long Length, WriteTicks, CreationTicks;
 public PzBackupFile(long length,long write,long creation){Length=length;WriteTicks=write;CreationTicks=creation;}
 public bool Same(PzBackupFile b){return b!=null&&Length==b.Length&&WriteTicks==b.WriteTicks&&(CreationTicks==0||b.CreationTicks==0||CreationTicks==b.CreationTicks);}
}
public sealed class PzBackupIndex {
 public string Root, Profile, ArchiveName, ArchiveHash;
 public long ArchiveTimeTicks;
 public Dictionary<string,PzBackupFile> Files=new Dictionary<string,PzBackupFile>(StringComparer.OrdinalIgnoreCase);
 public HashSet<string> Directories=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
 static void Safe(string path){
  if(String.IsNullOrEmpty(path)||Path.IsPathRooted(path)||path.IndexOf(':')>=0||path.IndexOf('\t')>=0||path.IndexOf('\n')>=0||path.IndexOf('\r')>=0)throw new IOException("Unsafe index path");
  foreach(string part in path.Replace('\\','/').Split('/'))if(part==".."||part==".")throw new IOException("Unsafe index segment");
 }
 string Relative(string full){
  full=Path.GetFullPath(full);
  if(!full.StartsWith(Root,StringComparison.OrdinalIgnoreCase))throw new IOException("Source outside backup root");
  string rel=full.Substring(Root.Length).Replace('\\','/');Safe(rel);return rel;
 }
 void AddFile(FileInfo file){Files[Relative(file.FullName)]=new PzBackupFile(file.Length,file.LastWriteTimeUtc.Ticks,file.CreationTimeUtc.Ticks);}
 public static PzBackupIndex Scan(string root,string profile,string[] sources){
  var result=new PzBackupIndex();result.Root=Path.GetFullPath(root).TrimEnd('\\','/')+Path.DirectorySeparatorChar;result.Profile=profile;
  foreach(string source in sources){
   string full=Path.GetFullPath(Path.Combine(root,source));
   if(File.Exists(full)){result.AddFile(new FileInfo(full));continue;}
   if(!Directory.Exists(full))continue;
   var pending=new Stack<DirectoryInfo>();pending.Push(new DirectoryInfo(full));
   while(pending.Count>0){
    var dir=pending.Pop();
    if((dir.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Resolve linked save directory before backup: "+dir.FullName);
    result.Directories.Add(result.Relative(dir.FullName));
    foreach(var file in dir.EnumerateFiles())result.AddFile(file);
    foreach(var child in dir.EnumerateDirectories())pending.Push(child);
   }
  }
  return result;
 }
 public bool Equivalent(PzBackupIndex other){
  if(!String.Equals(Root,other.Root,StringComparison.OrdinalIgnoreCase)||Profile!=other.Profile||Files.Count!=other.Files.Count||!Directories.SetEquals(other.Directories))return false;
  foreach(var row in Files){PzBackupFile value;if(!other.Files.TryGetValue(row.Key,out value)||!row.Value.Same(value))return false;}return true;
 }
 public string[] Changed(PzBackupIndex previous){
  var result=new List<string>();
  foreach(var row in Files){PzBackupFile value;if(!previous.Files.TryGetValue(row.Key,out value)||!row.Value.Same(value)||(value.CreationTicks==0&&previous.ArchiveTimeTicks>0&&row.Value.CreationTicks>previous.ArchiveTimeTicks))result.Add(row.Key);}
  result.Sort(StringComparer.OrdinalIgnoreCase);return result.ToArray();
 }
 public string[] Removed(PzBackupIndex current){
  var result=new List<string>();foreach(var path in Files.Keys)if(!current.Files.ContainsKey(path))result.Add(path);
  foreach(var path in Directories)if(!current.Directories.Contains(path))result.Add(path+"/");
  result.Sort(StringComparer.OrdinalIgnoreCase);return result.ToArray();
 }
 public void ValidateZip(IEnumerable entries){
  int count=0;PropertyInfo name=null,length=null;var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  foreach(object entry in entries){
   if(name==null){name=entry.GetType().GetProperty("FullName");length=entry.GetType().GetProperty("Length");}
   string path=((string)name.GetValue(entry,null)).Replace('\\','/');if(path.EndsWith("/"))continue;
   Safe(path);PzBackupFile file;
   if(!seen.Add(path)||!Files.TryGetValue(path,out file)||file.Length!=(long)length.GetValue(entry,null))throw new IOException("ZIP does not match current source: "+path);
   count++;
  }
  if(count!=Files.Count)throw new IOException("ZIP file count differs from source");
 }
 public void Save(string path){
  using(var w=new StreamWriter(path,false,new UTF8Encoding(false))){
   w.WriteLine("PZBACKUP1");w.WriteLine(Convert.ToBase64String(Encoding.UTF8.GetBytes(Root)));w.WriteLine(Profile);w.WriteLine(ArchiveName);w.WriteLine(ArchiveHash);
   var names=new List<string>(Files.Keys);names.Sort(StringComparer.OrdinalIgnoreCase);
   foreach(string name in names){var f=Files[name];w.WriteLine("F\t"+name+"\t"+f.Length+"\t"+f.WriteTicks+"\t"+f.CreationTicks);}
   names=new List<string>(Directories);names.Sort(StringComparer.OrdinalIgnoreCase);foreach(string name in names)w.WriteLine("D\t"+name);
  }
 }
 public void VerifyPayload(IEnumerable entries){
  using(var sha=System.Security.Cryptography.SHA256.Create()){
   foreach(object entry in entries){
    string path=((string)entry.GetType().GetProperty("FullName").GetValue(entry,null)).Replace('\\','/');if(path.EndsWith("/"))continue;Safe(path);
    byte[] zipped,source;
    using(var input=(Stream)entry.GetType().GetMethod("Open",Type.EmptyTypes).Invoke(entry,null))zipped=sha.ComputeHash(input);
    using(var input=File.OpenRead(Path.Combine(Root,path)))source=sha.ComputeHash(input);
    if(!System.Collections.StructuralComparisons.StructuralEqualityComparer.Equals(zipped,source))throw new IOException("Restored content differs: "+path);
   }
  }
 }
 public static PzBackupIndex Load(string path){
  var result=new PzBackupIndex();
  using(var r=new StreamReader(path,Encoding.UTF8)){
   if(r.ReadLine()!="PZBACKUP1")throw new IOException("Unknown backup index");
   result.Root=Encoding.UTF8.GetString(Convert.FromBase64String(r.ReadLine()));result.Profile=r.ReadLine();result.ArchiveName=r.ReadLine();result.ArchiveHash=r.ReadLine();
   if(Path.GetFileName(result.ArchiveName)!=result.ArchiveName||!result.ArchiveName.EndsWith(".zip",StringComparison.OrdinalIgnoreCase))throw new IOException("Unsafe baseline archive");
   if(result.ArchiveHash==null||result.ArchiveHash.Length!=64)throw new IOException("Missing archive hash");
   string line;while((line=r.ReadLine())!=null){var p=line.Split('\t');
    if(p.Length<2)throw new IOException("Invalid index record");Safe(p[1]);
    if(p[0]=="F"&&p.Length==5)result.Files.Add(p[1],new PzBackupFile(Int64.Parse(p[2]),Int64.Parse(p[3]),Int64.Parse(p[4])));
    else if(p[0]=="D"&&p.Length==2)result.Directories.Add(p[1]);else throw new IOException("Invalid index record");
   }
  }return result;
 }
 static long ListingTime(string value){
  if(String.IsNullOrEmpty(value))return 0;
  return DateTime.Parse(value,System.Globalization.CultureInfo.InvariantCulture,System.Globalization.DateTimeStyles.AssumeLocal).ToUniversalTime().Ticks;
 }
 static void ListingRecord(PzBackupIndex index,Dictionary<string,string> row){
  string path;if(!row.TryGetValue("Path",out path))return;path=path.Replace('\\','/').TrimEnd('/');Safe(path);
  if(row["Folder"]=="+"){index.Directories.Add(path);return;}
  string flags;row.TryGetValue("Characteristics",out flags);
  if(flags==null||flags.IndexOf("NTFS",StringComparison.Ordinal)<0)throw new IOException("Baseline lacks precise NTFS timestamps; make a full baseline");
  foreach(char c in path)if(c>127&&flags.IndexOf("UTF8",StringComparison.OrdinalIgnoreCase)<0)throw new IOException("Legacy filename encoding needs a fresh UTF-8 baseline");
  long time=ListingTime(row["Modified"]);if(time<=0)throw new IOException("Missing baseline modification time");
  string created;row.TryGetValue("Created",out created);
  index.Files.Add(path,new PzBackupFile(Int64.Parse(row["Size"]),time,ListingTime(created)));
 }
 public static PzBackupIndex FromSevenZipListing(string listing,string root,string profile,string archiveName,string hash){
  var index=new PzBackupIndex();index.Root=Path.GetFullPath(root).TrimEnd('\\','/')+Path.DirectorySeparatorChar;index.Profile=profile;index.ArchiveName=archiveName;index.ArchiveHash=hash;
  var row=new Dictionary<string,string>();
  using(var input=new StreamReader(listing,Encoding.UTF8)){
   string line;while((line=input.ReadLine())!=null){
    if(line.Length==0){ListingRecord(index,row);row.Clear();continue;}
    int split=line.IndexOf(" = ",StringComparison.Ordinal);if(split>0)row[line.Substring(0,split)]=line.Substring(split+3);
   }
  }ListingRecord(index,row);if(index.Files.Count==0)throw new IOException("No baseline files");return index;
 }
}
