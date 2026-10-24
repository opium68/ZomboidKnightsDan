import java.nio.file.*;
import java.util.regex.*;
import java.lang.reflect.*;

/** Exercise the overlay with the installed game parser, without opening a save. */
public class P19AExitTest {
    static Object call(Object obj, String method, Object... args) throws Exception { for (Method m : obj.getClass().getMethods()) if (m.getName().equals(method) && m.getParameterCount()==args.length) return m.invoke(obj,args); throw new NoSuchMethodException(method); }
    static Object field(Object obj, String name) throws Exception { return obj.getClass().getField(name).get(obj); }
    static float number(Object obj, String name) throws Exception { return ((Number)field(obj,name)).floatValue(); }
    public static void main(String[] args) throws Exception {
        String lua = Files.readString(Path.of(args[0]));
        Matcher m = Pattern.compile("local overlay = \\[\\[([\\s\\S]*?)\\]\\]").matcher(lua);
        if (!m.find()) throw new AssertionError("Missing overlay");
        String[] ids = {"FrontLeft", "FrontRight", "RearLeft", "RearRight"};
        Object script = Class.forName("zombie.scripting.objects.VehicleScript").getConstructor().newInstance();
        String fixture = "vehicle 86oshkoshUSMC { extents = 2.7556 2.2667 7.9111, part Engine { itemType = Base.Engine, }";
        for (String id : ids) fixture += " passenger " + id + " { door = Door" + id + ", position inside { offset = 0.5 0.03 2.9, } position outside { offset = 0 0 0, area = OldArea, } anim exit { anim = Climb_WindowB, rate = 0.23, } }";
        call(script,"Load","86oshkoshUSMC",fixture + "}");
        Object engine = call(script,"getPartById","Engine");
        Object[] passengers = new Object[4], inside = new Object[4], animations = new Object[4];
        for (int i=0; i<4; i++) {
            var p = call(script,"getPassengerById",ids[i]);
            passengers[i] = p;
            inside[i] = call(p,"getPositionById","inside");
            animations[i] = ((java.util.List<?>)field(p,"anims")).get(0);
        }
        call(script,"Load","86oshkoshUSMC",m.group(1));
        // Repeated boot configuration must not append duplicate passengers/areas.
        call(script,"Load","86oshkoshUSMC",m.group(1));
        if (!call(script,"getPassengerCount").equals(4) || !call(script,"getAreaCount").equals(4) || call(script,"getPartById","Engine")!=engine)
            throw new AssertionError("Existing structure lost or duplicated");
        for (int i=0; i<4; i++) {
            var p = call(script,"getPassengerById",ids[i]);
            if (p!=passengers[i] || call(p,"getPositionById","inside")!=inside[i] || ((java.util.List<?>)field(p,"anims")).get(0)!=animations[i])
                throw new AssertionError("Seat or animation replaced: " + ids[i]);
            var pos = call(p,"getPositionById","outside");
            var area = call(script,"getAreaById",field(pos,"area"));
            // Native areaPositionWorld4PlayerInteract shifts side areas inward by w*0.3.
            float x = number(area,"x") - Math.signum(number(area,"x"))*number(area,"w")*0.3f;
            if (Math.abs(x-number(field(pos,"offset"),"x"))>0.0001f || Math.abs(number(area,"y")-number(field(pos,"offset"),"z"))>0.0001f)
                throw new AssertionError("Exit check/final position mismatch: " + ids[i]);
            float clearance = Math.abs(x)-number(call(script,"getExtents"),"x")/2f;
            if (clearance<0.5f) throw new AssertionError("Insufficient side clearance: " + ids[i]);
            System.out.println("PASS " + ids[i] + " exit=("+x+", "+number(area,"y")+") side clearance="+clearance);
        }
        System.out.println("PASS native overlay merge: four exits, original seats/animations/parts preserved, repeat-safe");
    }
}
