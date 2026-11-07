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
    private static byte[] protect(String owner,byte[] bytes)throws Exception {
        int[] count={0};
        Object cl=transform("ClassTransform",(builder,element)->{
            if(c("MethodModel").isInstance(element)) {
                Object entry=c("MethodModel").getMethod("methodName").invoke(element);
                String name=(String)c("constantpool.Utf8Entry").getMethod("stringValue").invoke(entry);
                String desc=(String)c("constantpool.Utf8Entry").getMethod("stringValue").invoke(c("MethodModel").getMethod("methodType").invoke(element));
                boolean square=owner.equals("zombie/iso/IsoGridSquare");
                boolean burn=square && java.util.Set.of("Burn","BurnWalls","BurnWallsTCOnly","BurnTick").contains(name) && desc.endsWith(")V");
                boolean remove=square && java.util.Set.of("RemoveTileObject","RemoveTileObjectErosionNoRecalc","transmitRemoveItemFromSquare","transmitRemoveItemFromSquareOnClients").contains(name) && desc.startsWith("(Lzombie/iso/IsoObject;");
                boolean fence=(owner.endsWith("/BrokenFences")||owner.endsWith("/BentFences")) && (name.equals("destroyFence")||name.equals("bendFence")) && desc.startsWith("(Lzombie/iso/IsoObject;") && desc.endsWith(")V");
                boolean object=!square && !owner.endsWith("Fences") && java.util.Set.of("Damage","Thump","destroyFence","handleBurning","destroy","WeaponHit").contains(name) && desc.endsWith(")V");
                if(burn||remove||fence||object){
                    int slot=(remove||fence)?1:0;boolean integer=desc.endsWith(")I");
                    Object mt=transform("MethodTransform",(mb,me)->{
                        if(c("CodeModel").isInstance(me)){
                            boolean[] inserted={false};
                            Object ct=transform("CodeTransform",(cb,ce)->{
                                if(!inserted[0] && c("Instruction").isInstance(ce)){
                                    inserted[0]=true;
                                    c("CodeBuilder").getMethod("aload",int.class).invoke(cb,slot);
                                    c("CodeBuilder").getMethod("invokestatic",ClassDesc.class,String.class,MethodTypeDesc.class).invoke(cb,ClassDesc.of("raccoon.RCEProtection"),burn?"square":"object",MethodTypeDesc.ofDescriptor(burn?"(Lzombie/iso/IsoGridSquare;)Z":"(Lzombie/iso/IsoObject;)Z"));
                                    java.util.function.Consumer<Object> ret=b->{try{
                                        if(integer)c("CodeBuilder").getMethod("iconst_m1").invoke(b);
                                        c("CodeBuilder").getMethod(integer?"ireturn":"return_").invoke(b);
                                    }catch(Exception e){throw new RuntimeException(e);}};
                                    c("CodeBuilder").getMethod("ifThen",java.util.function.Consumer.class).invoke(cb,ret);
                                }
                                with(cb,ce);
                            });
                            c("MethodBuilder").getMethod("transformCode",c("CodeModel"),c("CodeTransform")).invoke(mb,me,ct);
                        }else with(mb,me);
                    });
                    c("ClassBuilder").getMethod("transformMethod",c("MethodModel"),c("MethodTransform")).invoke(builder,element,mt);
                    count[0]++;return;
                }
            }
            with(builder,element);
        });
        Object api=c("ClassFile").getMethod("of").invoke(null);
        Object model=c("ClassFile").getMethod("parse",byte[].class).invoke(api,bytes);
        byte[] result=(byte[])c("ClassFile").getMethod("transformClass",c("ClassModel"),c("ClassTransform")).invoke(api,model,cl);
        if(count[0]==0)throw new IllegalStateException("No barrier methods matched "+owner);
        System.out.println("[RCE_AGENT] barrier guards "+owner+" methods="+count[0]);
        return result;
    }
    public static void premain(String ignored, Instrumentation instrumentation) {
        System.out.println("[RCE_AGENT] armed");
        instrumentation.addTransformer(new ClassFileTransformer() {
            public byte[] transform(ClassLoader loader, String name, Class<?> cls,
                                    ProtectionDomain domain, byte[] bytes) {
                if (!"zombie/Lua/LuaManager".equals(name)) {
                    if(java.util.Set.of("zombie/iso/IsoObject","zombie/iso/objects/IsoThumpable","zombie/iso/IsoGridSquare","zombie/iso/BrokenFences","zombie/iso/BentFences").contains(name))
                        try{return protect(name,bytes);}catch(Exception e){e.printStackTrace();throw new IllegalStateException("Barrier guard failed "+name,e);}
                    return null;
                }
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
