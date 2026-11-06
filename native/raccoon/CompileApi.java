import java.nio.file.*;
import java.util.zip.*;
/** Compile-time API view for javac21. NEVER put this jar on a game classpath.
 * Original engine bytes are untouched; the running bridge uses the JDK25 game. */
public final class CompileApi {
    public static void main(String[] args) throws Exception {
        Path input=Path.of(args[0]).toRealPath(), output=Path.of(args[1]).toAbsolutePath().normalize();
        if(!output.getFileName().toString().equals("compile-api.jar") || input.equals(output))
            throw new IllegalArgumentException("Only a separate compile-api.jar output is accepted");
        try(ZipFile source=new ZipFile(input.toFile());ZipOutputStream out=new ZipOutputStream(Files.newOutputStream(output))) {
            var entries=source.entries();
            while(entries.hasMoreElements()) {
                var entry=entries.nextElement();if(!entry.getName().endsWith(".class")) continue;
                byte[] bytes=source.getInputStream(entry).readAllBytes();
                int major=((bytes[6]&255)<<8)|(bytes[7]&255);
                if(major>65){bytes[6]=0;bytes[7]=65;}
                out.putNextEntry(new ZipEntry(entry.getName()));out.write(bytes);out.closeEntry();
            }
        }
    }
}
