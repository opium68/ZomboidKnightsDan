package raccoon;

import java.io.*;
import java.nio.file.*;
import java.sql.*;
import java.time.Instant;
import java.util.*;
import java.util.regex.*;
import java.util.zip.*;

/** Offline restart gate. No shell file deletion and no whole-world metadata
 * deletion. Apply requires an explicit clean-stop receipt from the launcher. */
public final class OfflineReset {
    static final int X1=9728,Y1=9728,X2=10496,Y2=10752;
    static boolean in(int x,int y){return x>=X1 && x<X2 && y>=Y1 && y<Y2;}
    static boolean scoped(Path root,Path file) {
        Path relative=root.relativize(file);String name=file.getFileName().toString();
        String directory=relative.getName(0).toString();
        if((directory.equals("map") || directory.equals("blam")) && relative.getNameCount()==3) {
            try{return in(Integer.parseInt(relative.getName(1).toString())*8,Integer.parseInt(name.replaceFirst("\\.bin$",""))*8);}
            catch(NumberFormatException ex){return false;}
        }
        if(Set.of("chunkdata","zpop","metagrid","apop").contains(directory)) {
            Matcher match=Pattern.compile("(?:chunkdata|zpop|metacell|apop)_(-?\\d+)_(-?\\d+)\\.bin").matcher(name);
            return match.matches() && in(Integer.parseInt(match.group(1))*256,Integer.parseInt(match.group(2))*256);
        }
        return false;
    }
    static Properties read(Path path)throws Exception{Properties p=new Properties();try(var r=Files.newBufferedReader(path)){p.load(r);}return p;}
    static Connection open(Path db,boolean readOnly)throws Exception{
        if(!Files.isRegularFile(db))throw new IllegalStateException("Missing database: "+db.getFileName());
        return DriverManager.getConnection("jdbc:sqlite:"+db.toUri()+ (readOnly?"?mode=ro":"?mode=rw"));
    }
    public static void main(String[] args)throws Exception{
        if(args.length!=3 || !Set.of("inspect","apply","initialize").contains(args[2]))throw new IllegalArgumentException("cache-root server-name inspect|apply|initialize");
        Path cache=Path.of(args[0]).toRealPath();String name=args[1];
        if(!name.matches("[A-Za-z0-9_-]+"))throw new IllegalArgumentException("Invalid server name");
        Path world=cache.resolve("Saves/Multiplayer/"+name).toRealPath();
        if(!world.startsWith(cache))throw new IllegalStateException("World escapes cache root");
        boolean initial=args[2].equals("initialize");
        Path checkpoint=cache.resolve("Lua/RCE-"+name+"-checkpoint.txt");
        Path initialized=cache.resolve("Lua/RCE-"+name+"-initialized.txt");
        Properties state;
        if(initial) {
            if(Files.exists(checkpoint)||Files.exists(initialized))throw new IllegalStateException("Expedition already initialized");
            String log=Files.readString(cache.resolve("server-console.txt"));
            if(log.lastIndexOf("Shutdown handling finished")<=log.lastIndexOf("SERVER STARTED"))throw new IllegalStateException("Clean server shutdown required for installation");
            state=new Properties();state.setProperty("cycle","0");state.setProperty("registryOccupants","0");
        } else {
            state=read(checkpoint);
            if(!"1".equals(state.getProperty("version")) || !name.equals(state.getProperty("world")))throw new IllegalStateException("Invalid checkpoint");
        }
        Class.forName("org.sqlite.JDBC");
        int occupants;
        try(Connection c=open(world.resolve("players.db"),true);PreparedStatement s=c.prepareStatement(
            "SELECT COUNT(*) FROM networkPlayers WHERE isDead=0 AND x>=? AND x<? AND y>=? AND y<?")){
            // This save folder is one world. Do not accidentally exclude rows
            // whose DB world field has a different historical identifier.
            s.setInt(1,X1);s.setInt(2,X2);s.setInt(3,Y1);s.setInt(4,Y2);
            try(ResultSet rs=s.executeQuery()){rs.next();occupants=rs.getInt(1);}
        }
        if(occupants>0 || Integer.parseInt(state.getProperty("registryOccupants"))>0){System.out.println("RCE_RESET=OCCUPIED db="+occupants);return;}
        List<Path> files;
        try(var paths=Files.walk(world)){files=paths.filter(Files::isRegularFile).filter(p->scoped(world,p)).sorted().toList();}
        System.out.println("RCE_RESET=ELIGIBLE files="+files.size()+" policy=empty-on-restart");
        if(args[2].equals("inspect"))return;
        Path clean=cache.resolve("RCE-"+name+"-clean-stop.properties");
        if(!initial) {
            // An uncertain shutdown prevents DELETION, not ordinary startup.
            // Never invent a receipt or reset instruction to get past this gate.
            if(!Files.isRegularFile(clean)) {
                System.out.println("RCE_RESET=DEFERRED reason=missing-clean-stop preserve-world=true");return;
            }
            Properties receipt;
            try { receipt=read(clean); }
            catch(IOException | IllegalArgumentException unreadable) {
                System.out.println("RCE_RESET=DEFERRED reason=unreadable-clean-stop preserve-world=true");return;
            }
            String savedAt=state.getProperty("savedAt");
            if(savedAt==null || !savedAt.matches("\\d+") || !savedAt.equals(receipt.getProperty("savedAt"))) {
                System.out.println("RCE_RESET=DEFERRED reason=unmatched-clean-stop preserve-world=true");return;
            }
        }
        // The launcher checks process exit too. This guard rejects accidental
        // application while a Java server for this cache is still running.
        for(ProcessHandle p:ProcessHandle.allProcesses().toList()) {
            if(p.pid()==ProcessHandle.current().pid())continue;
            var command=p.info().commandLine();
            if(command.isPresent() && command.get().contains("zombie.network.GameServer") && command.get().contains(name))
                throw new IllegalStateException("A matching game server is still running");
        }
        Path backupRoot=cache.resolve("RCE-backups");Files.createDirectories(backupRoot);
        Path zip=backupRoot.resolve("cycle-"+state.getProperty("cycle")+"-"+Instant.now().toEpochMilli()+".zip");
        List<Path> backupFiles=new ArrayList<>(files);
        for(String db:List.of("vehicles.db","vehicles.db-journal","vehicles.db-wal","vehicles.db-shm")) {
            Path f=world.resolve(db);if(Files.isRegularFile(f))backupFiles.add(f);
        }
        try(ZipOutputStream output=new ZipOutputStream(Files.newOutputStream(zip,StandardOpenOption.CREATE_NEW))){
            for(Path f:backupFiles){output.putNextEntry(new ZipEntry(world.relativize(f).toString().replace('\\','/')));Files.copy(f,output);output.closeEntry();}
        }
        // Verify every backed-up file's CRC before mutating anything.
        try(ZipFile saved=new ZipFile(zip.toFile())) {
            for(Path f:backupFiles) {
                String key=world.relativize(f).toString().replace('\\','/');ZipEntry entry=saved.getEntry(key);
                CRC32 crc=new CRC32();try(InputStream input=Files.newInputStream(f)){byte[] buffer=new byte[65536];int n;while((n=input.read(buffer))!=-1)crc.update(buffer,0,n);}
                if(entry==null || entry.getSize()!=Files.size(f) || entry.getCrc()!=crc.getValue())throw new IOException("Backup verification failed");
            }
        }
        Path transaction=cache.resolve("RCE-"+name+"-reset-in-progress");
        Files.writeString(transaction,zip.toString(),StandardOpenOption.CREATE_NEW);
        try(Connection c=open(world.resolve("vehicles.db"),false);PreparedStatement s=c.prepareStatement(
            "DELETE FROM vehicles WHERE x>=? AND x<? AND y>=? AND y<?")){
            c.setAutoCommit(false);s.setInt(1,X1);s.setInt(2,X2);s.setInt(3,Y1);s.setInt(4,Y2);s.executeUpdate();c.commit();
        }
        for(Path f:files){if(!f.toRealPath().startsWith(world))throw new IOException("Scoped path escaped world");Files.delete(f);}
        Files.createDirectories(cache.resolve("Lua"));
        if(initial) Files.writeString(initialized,"version=1\nbackup="+zip.getFileName()+"\n",StandardOpenOption.CREATE_NEW);
        else {
            Path reset=cache.resolve("Lua/RCE-"+name+"-reset.txt");
            Files.writeString(reset,"version=1\nworld="+name+"\nfromCycle="+state.getProperty("cycle")+"\n");
        }
        Files.deleteIfExists(clean);Files.delete(transaction);
        System.out.println("RCE_RESET=APPLIED backup="+zip.getFileName());
    }
}
