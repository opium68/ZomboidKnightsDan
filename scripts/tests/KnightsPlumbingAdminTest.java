import java.io.*;
import java.nio.file.*;
import java.lang.reflect.*;

public class KnightsPlumbingAdminTest {
    public static void main(String[] args) throws Exception {
        Class<?> platformType = Class.forName("se.krka.kahlua.vm.Platform");
        Class<?> tableType = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Class<?> platformClass = Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Object platform = platformClass.getMethod("getInstance").invoke(null);
        Object env = platformClass.getMethod("newEnvironment").invoke(platform);
        Class<?> threadClass = Class.forName("se.krka.kahlua.vm.KahluaThread");
        Object thread = threadClass.getConstructor(platformType, tableType).newInstance(platform, env);
        threadClass.getField("debugOwnerThread").set(thread, Thread.currentThread());
        Method compile = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler")
            .getMethod("loadis", Reader.class, String.class, tableType);
        Class<?> functionType = Class.forName("se.krka.kahlua.vm.JavaFunction");
        Object loader = Proxy.newProxyInstance(functionType.getClassLoader(), new Class<?>[]{functionType},
            (proxy, method, values) -> {
                Object frame = values[0];
                String path = Path.of(args[1]).resolve((String)frame.getClass().getMethod("get", int.class).invoke(frame, 0)).toString();
                if (!Files.isRegularFile(Path.of(path)))
                    return frame.getClass().getMethod("push", Object.class).invoke(frame, new Object[]{null});
                try (var reader = Files.newBufferedReader(Path.of(path))) {
                    Object closure = compile.invoke(null, reader, path, env);
                    return frame.getClass().getMethod("push", Object.class).invoke(frame, closure);
                }
            });
        tableType.getMethod("rawset", Object.class, Object.class).invoke(env, "loadfile", loader);
        try (var reader = Files.newBufferedReader(Path.of(args[0]))) {
            Object closure = compile.invoke(null, reader, args[0], env);
            Object[] result = (Object[])threadClass.getMethod("pcall", Object.class, Object[].class)
                .invoke(thread, closure, new Object[0]);
            if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(java.util.Arrays.toString(result));
            System.out.println("PASS native Kahlua: " + result[1]);
        }
    }
}
