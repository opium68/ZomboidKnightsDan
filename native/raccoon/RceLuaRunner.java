package raccoon;

import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.lang.reflect.*;
import java.util.*;

/** Kahlua behavior runner with Lua-compatible module return values. */
public final class RceLuaRunner {
 public static void main(String[] args)throws Exception{
  Class<?> platformClass=Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
  Class<?> tableClass=Class.forName("se.krka.kahlua.vm.KahluaTable");
  Class<?> threadClass=Class.forName("se.krka.kahlua.vm.KahluaThread");
  Class<?> fnClass=Class.forName("se.krka.kahlua.vm.JavaFunction");
  Class<?> frameClass=Class.forName("se.krka.kahlua.vm.LuaCallFrame");
  Object platform=platformClass.getMethod("getInstance").invoke(null);
  Object env=platformClass.getMethod("newEnvironment").invoke(platform);
  Object thread=threadClass.getConstructor(Class.forName("se.krka.kahlua.vm.Platform"),tableClass).newInstance(platform,env);
  threadClass.getField("debugOwnerThread").set(thread,Thread.currentThread());
  Method compile=Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadis",java.io.Reader.class,String.class,tableClass);
  Method pcall=threadClass.getMethod("pcall",Object.class,Object[].class);
  Map<String,Object> loaded=new HashMap<>();
  Object require=Proxy.newProxyInstance(fnClass.getClassLoader(),new Class<?>[]{fnClass},(proxy,method,params)->{
   if(!method.getName().equals("call"))return null;
   Object frame=params[0];String name=String.valueOf(frameClass.getMethod("get",int.class).invoke(frame,0));
   if(!loaded.containsKey(name)){
    loaded.put(name,true);Path source=null;
    for(int i=1;i<args.length;i++){Path p=Path.of(args[i],name+".lua");if(Files.isRegularFile(p)){source=p;break;}}
    if(source==null)throw new IllegalArgumentException("Missing module: "+name);
    Object[] result;
    try(var reader=Files.newBufferedReader(source,StandardCharsets.UTF_8)){
     result=(Object[])pcall.invoke(thread,compile.invoke(null,reader,source.toString(),env),(Object)new Object[0]);
    }
    if(!Boolean.TRUE.equals(result[0]))throw new IllegalStateException(Arrays.toString(result));
    loaded.put(name,result.length>1 && result[1]!=null?result[1]:true);
   }
   frameClass.getMethod("push",Object.class).invoke(frame,loaded.get(name));return 1;
  });
  tableClass.getMethod("rawset",Object.class,Object.class).invoke(env,"require",require);
  Object[] result;
  try(var reader=Files.newBufferedReader(Path.of(args[0]),StandardCharsets.UTF_8)){
   result=(Object[])pcall.invoke(thread,compile.invoke(null,reader,args[0],env),(Object)new Object[0]);
  }
  if(!Boolean.TRUE.equals(result[0]))throw new IllegalStateException(Arrays.toString(result));
  System.out.println("RCE_LUA_PASS "+Path.of(args[0]).getFileName()+" "+Arrays.toString(result));
 }
}
