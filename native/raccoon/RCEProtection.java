package raccoon;
import zombie.iso.IsoObject;
import zombie.iso.IsoGridSquare;
/** Only original outer barricades, never dungeon/puzzle doors or ordinary walls. */
public final class RCEProtection {
 public static boolean location(int x,int y,int z,String name){
  if(z!=0 || x<9909 || x>10496 || y<9899 || y>10500)return false;
  if(x>9911 && x<10494 && y>9901 && y<10498)return false;
  if(name==null)return false;
  return java.util.Set.of("shisan_otherfurniture_0","shisan_otherfurniture_1","shisan_otherfurniture_2","shisan_otherfurniture_27",
   "shisan_furnace_80","shisan_furnace_81","shisan_furnace_82","shisan_furnace_83","shisan_furnace_84","shisan_furnace_85","shisan_furnace_86","shisan_furnace_87").contains(name);
 }
 public static boolean object(IsoObject o){
  if(o==null || o.getSquare()==null || o.getSprite()==null)return false;
  IsoGridSquare s=o.getSquare();return location(s.getX(),s.getY(),s.getZ(),o.getSprite().getName());
 }
 public static boolean square(IsoGridSquare s){
  if(s==null)return false;
  for(IsoObject o:s.getObjects())if(object(o))return true;
  return false;
 }
}
