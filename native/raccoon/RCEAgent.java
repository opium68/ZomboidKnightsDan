package raccoon;

import java.lang.instrument.*;
import java.security.ProtectionDomain;
import java.lang.reflect.*;
import java.lang.constant.*;

/** Installs a narrow bridge after LuaManager.init, before mod Lua loads.
 * Opt-in launch argument; does not replace files in the game installation. */
public final class RCEAgent {
    public static volatile int hookCount;
    private static Class<?> c(String suffix)throws Exception{return Class.forName("java.lang.classfile."+suffix);}
    @FunctionalInterface private interface Transform {void accept(Object builder,Object element)throws Exception;}
    private static Object transform(String kind,Transform function)throws Exception{
        Class<?> api=c(kind);
        return Proxy.newProxyInstance(api.getClassLoader(),new Class<?>[]{api},(p,m,args)->{
            if(m.getName().equals("accept")){function.accept(args[0],args[1]);return null;}
            if(m.isDefault())return InvocationHandler.invokeDefault(p,m,args==null?new Object[0]:args);
            if(m.getName().equals("toString"))return "RCE "+kind;
            throw new UnsupportedOperationException(m.getName());
        });
    }
    private static void with(Object builder,Object element)throws Exception{
        c("ClassFileBuilder").getMethod("with",c("ClassFileElement")).invoke(builder,element);
    }
    public static void premain(String ignored, Instrumentation instrumentation) {
        System.out.println("[RCE_AGENT] armed");
        instrumentation.addTransformer(new ClassFileTransformer() {
            public byte[] transform(ClassLoader loader, String name, Class<?> cls,
                                    ProtectionDomain domain, byte[] bytes) {
                if (!"zombie/Lua/LuaManager".equals(name)) return null;
                try {
                    // JDK25's supported Class-File API, accessed reflectively so
                    // the agent itself can be built by the available javac21.
                    Object code=RCEAgent.transform("CodeTransform",(builder,element)->{
                        if(c("instruction.ReturnInstruction").isInstance(element))
                            c("CodeBuilder").getMethod("invokestatic",ClassDesc.class,String.class,MethodTypeDesc.class)
                                .invoke(builder,ClassDesc.of("raccoon.RCEBridge"),"install",MethodTypeDesc.ofDescriptor("()V"));
                        with(builder,element);
                    });
                    Object method=RCEAgent.transform("MethodTransform",(builder,element)->{
                        if(c("CodeModel").isInstance(element))
                            c("MethodBuilder").getMethod("transformCode",c("CodeModel"),c("CodeTransform")).invoke(builder,element,code);
                        else with(builder,element);
                    });
                    int[] patched={0};
                    Object cl=RCEAgent.transform("ClassTransform",(builder,element)->{
                        if(c("MethodModel").isInstance(element)) {
                            Object entry=c("MethodModel").getMethod("methodName").invoke(element);
                            String methodName=(String)c("constantpool.Utf8Entry").getMethod("stringValue").invoke(entry);
                            if(methodName.equals("init")) {
                                c("ClassBuilder").getMethod("transformMethod",c("MethodModel"),c("MethodTransform")).invoke(builder,element,method);
                                patched[0]++;return;
                            }
                        }
                        with(builder,element);
                    });
                    Object api=c("ClassFile").getMethod("of").invoke(null);
                    Object model=c("ClassFile").getMethod("parse",byte[].class).invoke(api,bytes);
                    byte[] output=(byte[])c("ClassFile").getMethod("transformClass",c("ClassModel"),c("ClassTransform")).invoke(api,model,cl);
                    if(patched[0]!=1)throw new IllegalStateException("Expected exactly one LuaManager.init");
                    System.out.println("[RCE_AGENT] LuaManager initialization hook installed");
                    hookCount++;
                    return output;
                }catch(Exception ex){ex.printStackTrace();throw new IllegalStateException("RCE Lua initialization hook failed",ex);}
            }
        });
    }
}
