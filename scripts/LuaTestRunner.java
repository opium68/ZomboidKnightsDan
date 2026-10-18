import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.lang.reflect.*;

/** Runs behavioral Lua tests using the server's actual Kahlua interpreter. */
public final class LuaTestRunner {
    public static void main(String[] args) throws Exception {
        if(args.length<2) throw new IllegalArgumentException("test.lua search-root...");
        Class<?> platformClass=Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Class<?> platformInterface=Class.forName("se.krka.kahlua.vm.Platform");
        Class<?> tableClass=Class.forName("se.krka.kahlua.vm.KahluaTable");
        Class<?> threadClass=Class.forName("se.krka.kahlua.vm.KahluaThread");
        Class<?> frameClass=Class.forName("se.krka.kahlua.vm.LuaCallFrame");
        Class<?> functionClass=Class.forName("se.krka.kahlua.vm.JavaFunction");
        Object platform=platformClass.getMethod("getInstance").invoke(null);
        Object env=platformClass.getMethod("newEnvironment").invoke(platform);
        Object thread=threadClass.getConstructor(platformInterface,tableClass).newInstance(platform,env);
        threadClass.getField("debugOwnerThread").set(thread,Thread.currentThread());
        Method load=Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadis",Reader.class,String.class,tableClass);
        Method pcall=threadClass.getMethod("pcall",Object.class,Object[].class);
        // Mirror the game's mod-scoped reader so source-overlay tests execute
        // installed Workshop code without shipping or editing upstream files.
        Path discoveredRoot=null;
        for(int i=1;i<args.length;i++) {
            Path candidate=Path.of(args[i]).toAbsolutePath().normalize();
            if(candidate.endsWith(Path.of("media","lua","shared"))) {
                candidate=candidate.getParent().getParent().getParent();
                Path info=candidate.resolve("mod.info");
                if(Files.isRegularFile(info) && Files.readString(info).contains("id=B42_PZLinux")) discoveredRoot=candidate;
            }
        }
        final Path nativeRoot=discoveredRoot;
        Object modReader=Proxy.newProxyInstance(functionClass.getClassLoader(),new Class<?>[]{functionClass},(proxy,method,params)->{
            if(!method.getName().equals("call")) return null;
            Object frame=params[0];
            String mod=String.valueOf(frameClass.getMethod("get",int.class).invoke(frame,0));
            String relative=String.valueOf(frameClass.getMethod("get",int.class).invoke(frame,1));
            if(!mod.equals("B42_PZLinux") || nativeRoot==null) throw new IllegalArgumentException("Unsupported test mod reader");
            Path source=nativeRoot.resolve(relative).normalize();
            if(!source.startsWith(nativeRoot) || !Files.isRegularFile(source)) throw new IllegalArgumentException("Invalid test source path");
            List<String> lines=Files.readAllLines(source,StandardCharsets.UTF_8);
            int[] index={0};
            Object reader=platformClass.getMethod("newTable").invoke(platform);
            Object readLine=Proxy.newProxyInstance(functionClass.getClassLoader(),new Class<?>[]{functionClass},(p,m,a)->{
                if(!m.getName().equals("call")) return null;
                frameClass.getMethod("push",Object.class).invoke(a[0],index[0]<lines.size()?lines.get(index[0]++):null);
                return 1;
            });
            Object close=Proxy.newProxyInstance(functionClass.getClassLoader(),new Class<?>[]{functionClass},(p,m,a)->m.getName().equals("call")?0:null);
            tableClass.getMethod("rawset",Object.class,Object.class).invoke(reader,"readLine",readLine);
            tableClass.getMethod("rawset",Object.class,Object.class).invoke(reader,"close",close);
            frameClass.getMethod("push",Object.class).invoke(frame,reader);
            return 1;
        });
        tableClass.getMethod("rawset",Object.class,Object.class).invoke(env,"getModFileReader",modReader);
        Set<String> loaded=new HashSet<>();
        Object require=Proxy.newProxyInstance(functionClass.getClassLoader(),new Class<?>[]{functionClass},(proxy,method,params)->{
            if(!method.getName().equals("call")) return null;
            Object frame=params[0];
            String name=String.valueOf(frameClass.getMethod("get",int.class).invoke(frame,0));
            if(!loaded.add(name)){frameClass.getMethod("push",Object.class).invoke(frame,Boolean.TRUE);return 1;}
            Path file=null;
            for(int i=1;i<args.length;i++){
                Path candidate=Path.of(args[i],name+".lua");
                if(Files.isRegularFile(candidate)){file=candidate;break;}
            }
            if(file==null) throw new IllegalStateException("Missing required module: "+name);
            try(var reader=Files.newBufferedReader(file,StandardCharsets.UTF_8)){
                Object closure=load.invoke(null,reader,file.toString(),env);
                Object[] result=(Object[])pcall.invoke(thread,closure,(Object)new Object[0]);
                if(!Boolean.TRUE.equals(result[0])) throw new IllegalStateException(Arrays.toString(result));
            }catch(IOException ex){throw new UncheckedIOException(ex);}
            frameClass.getMethod("push",Object.class).invoke(frame,Boolean.TRUE);return 1;
        });
        tableClass.getMethod("rawset",Object.class,Object.class).invoke(env,"require",require);
        try(var reader=Files.newBufferedReader(Path.of(args[0]),StandardCharsets.UTF_8)){
            Object[] result=(Object[])pcall.invoke(thread,load.invoke(null,reader,args[0],env),(Object)new Object[0]);
            if(!Boolean.TRUE.equals(result[0])){System.err.println(Arrays.toString(result));System.exit(1);}
            System.out.println("PASS Lua behavior test: "+args[0]+" "+Arrays.toString(result));
        }
    }
}
