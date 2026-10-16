import java.nio.file.*;
import java.util.regex.*;
import java.lang.reflect.*;

public class KnightsDisabledRecipeTest {
    public static void main(String[] args) throws Exception {
        Class.forName("zombie.core.Core").getField("debug").setBoolean(null, true);
        Class.forName("zombie.characters.skills.PerkFactory").getMethod("init").invoke(null);
        Field modId = Class.forName("zombie.scripting.ScriptManager").getDeclaredField("currentLoadFileMod");
        modId.setAccessible(true);
        modId.set(null, "KnightsDanServerPatch");
        Class<?> type = Class.forName("zombie.scripting.entity.components.crafting.CraftRecipe");
        Method load = type.getMethod("Load", String.class, String.class);
        int count = 0;
        for (String path : args) {
            String source = Files.readString(Path.of(path));
            Matcher m = Pattern.compile("craftRecipe\\s+(\\w+)\\s*\\{").matcher(source);
            while (m.find()) {
                int start = m.end() - 1, end = start + 1, depth = 1;
                while (depth > 0 && end < source.length()) {
                    char c = source.charAt(end++);
                    if (c == '{') depth++;
                    if (c == '}') depth--;
                }
                Object recipe = type.getConstructor().newInstance();
                Class<?> moduleType = Class.forName("zombie.scripting.objects.ScriptModule");
                Object module = moduleType.getConstructor().newInstance();
                moduleType.getField("name").set(module, "Base");
                type.getMethod("setModule", moduleType).invoke(recipe, module);
                type.getMethod("InitLoadPP", String.class).invoke(recipe, m.group(1));
                load.invoke(recipe, m.group(1), "craftRecipe " + m.group(1) + source.substring(start, end));
                if (((Number)type.getMethod("getRequiredSkillCount").invoke(recipe)).intValue() != 1
                    || ((Number)type.getMethod("getHighestSkillRequirement").invoke(recipe)).intValue() != 99)
                    throw new AssertionError("Manufacturing restriction lost: " + m.group(1));
                count++;
            }
        }
        if (count < 50) throw new AssertionError("Unexpected recipe count: " + count);
        System.out.println("PASS native debug CraftRecipe.Load: " + count + " blocked recipes; skill 99 preserved");
    }
}
