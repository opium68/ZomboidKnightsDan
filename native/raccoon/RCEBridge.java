package raccoon;

import java.util.*;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import zombie.characters.*;
import zombie.characters.skills.PerkFactory;
import zombie.iso.*;
import zombie.network.*;
import zombie.popman.NetworkZombiePacker;

/** Server-only engine operations. Clients cannot invoke these functions over
 * the network: all remote requests pass through the expedition's Lua rules. */
public final class RCEBridge {
    private static int integer(LuaCallFrame f,int at) {return ((Number)f.get(at)).intValue();}
    private static double number(LuaCallFrame f,int at) {return ((Number)f.get(at)).doubleValue();}
    private static int result(LuaCallFrame f,Object value) {f.push(value);return 1;}
    private static IsoGridSquare square(int x,int y,int z) {return ServerMap.instance.getGridSquare(x,y,z);}
    public static void install() {
        LuaManager.env.rawset("RCENativeKeep",(JavaFunction)(f,n)->{
            int x=integer(f,0),y=integer(f,1),radius=integer(f,2);
            for(int cx=ServerMap.instance.worldSquareToServerCellXY(x-radius);cx<=ServerMap.instance.worldSquareToServerCellXY(x+radius);cx++)
                for(int cy=ServerMap.instance.worldSquareToServerCellXY(y-radius);cy<=ServerMap.instance.worldSquareToServerCellXY(y+radius);cy++)
                    ServerMap.instance.importantAreaIn(cx,cy);
            return result(f,true);
        });
        LuaManager.env.rawset("RCENativeLoaded",(JavaFunction)(f,n)->{
            int x=integer(f,0),y=integer(f,1),z=integer(f,2),r=integer(f,3);
            // An upper floor legitimately has no squares in the outdoor air.
            // Readiness means loaded XY chunks; target-floor safety is separate.
            for(int cx=Math.floorDiv(x-r,8);cx<=Math.floorDiv(x+r,8);cx++)
                for(int cy=Math.floorDiv(y-r,8);cy<=Math.floorDiv(y+r,8);cy++)
                    if(ServerMap.instance.getChunk(cx,cy)==null) return result(f,false);
            return result(f,true);
        });
        LuaManager.env.rawset("RCENativeSafe",(JavaFunction)(f,n)->
            result(f,safe(integer(f,0),integer(f,1),integer(f,2),number(f,3))));
        LuaManager.env.rawset("RCENativeInspect",(JavaFunction)(f,n)->{
            int x=integer(f,0),y=integer(f,1),z=integer(f,2);IsoGridSquare s=square(x,y,z);
            if(s==null)return result(f,"unloaded");
            String value="floor="+s.TreatAsSolidFloor()+" free="+s.isFree(false);
            for(var vehicle:IsoWorld.instance.currentCell.getVehicles())
                if(Math.abs(vehicle.getX()-(x+0.5))<3 && Math.abs(vehicle.getY()-(y+0.5))<5)value+=" nearby-vehicle";
            return result(f,value);
        });
        LuaManager.env.rawset("RCENativeReachable",(JavaFunction)(f,n)->
            result(f,reachable(integer(f,0),integer(f,1),integer(f,2),integer(f,3),integer(f,4))));
        LuaManager.env.rawset("RCENativeClear",(JavaFunction)(f,n)->{
            int x=integer(f,0),y=integer(f,1),z=integer(f,2),r=integer(f,3),removed=0;
            var zombies=new ArrayList<>(IsoWorld.instance.currentCell.getZombieList());
            for(IsoZombie zombie:zombies) {
                double dx=zombie.getX()-x,dy=zombie.getY()-y;
                if((int)Math.floor(zombie.getZ())!=z || dx*dx+dy*dy>r*r) continue;
                // Same network deletion path as the built-in removezombies command;
                // no Hit/Kill/OnZombieDead call, corpse, inventory or XP award.
                NetworkZombiePacker.getInstance().deleteZombie(zombie);
                zombie.removeFromWorld();zombie.removeFromSquare();removed++;
            }
            return result(f,(double)removed);
        });
        LuaManager.env.rawset("RCENativeTeleport",(JavaFunction)(f,n)->{
            IsoPlayer p=(IsoPlayer)f.get(0);
            if(p==null || p.isDead() || p.getVehicle()!=null || !GameServer.isPlayerConnected(p)) return result(f,false);
            GameServer.sendTeleport(p,(float)number(f,1)+0.5f,(float)number(f,2)+0.5f,(float)number(f,3));
            return result(f,true);
        });
        LuaManager.env.rawset("RCENativePerks",(JavaFunction)(f,n)->{
            IsoPlayer p=(IsoPlayer)f.get(0);KahluaTable values=LuaManager.platform.newTable();
            for(PerkFactory.Perk perk:PerkFactory.PerkList)
                values.rawset(perk.getId(),(double)p.getXp().getXP(perk));
            return result(f,values);
        });
        LuaManager.env.rawset("RCENativeRestorePerks",(JavaFunction)(f,n)->{
            IsoPlayer p=(IsoPlayer)f.get(0);KahluaTable values=(KahluaTable)f.get(1);
            // OnCreate can precede a usable player connection. Do not mark
            // restoration complete before the server can synchronize skill XP.
            if(!GameServer.isPlayerConnected(p)) return result(f,false);
            for(PerkFactory.Perk perk:PerkFactory.PerkList) {
                Object raw=values.rawget(perk.getId());
                if(!(raw instanceof Number)) continue;
                float delta=((Number)raw).floatValue()-p.getXp().getXP(perk);
                if(Float.isFinite(delta) && delta>0) GameServer.addXp(p,perk,delta,true);
            }
            return result(f,true);
        });
        if(Boolean.getBoolean("rce.characterProbe")) {
            try {
                Class.forName("raccoon.CharacterProbeBridge").getMethod("install").invoke(null);
            } catch(ReflectiveOperationException error) {
                throw new IllegalStateException("Isolated character probe bridge unavailable",error);
            }
        }
        System.out.println("[RCE] Native server bridge installed");
    }
    private static boolean safe(int x,int y,int z,double zombieRadius) {
        IsoGridSquare s=square(x,y,z);
        if(s==null || !s.TreatAsSolidFloor() || !s.isFree(false)) return false;
        for(var object:s.getMovingObjects()) if(object instanceof IsoPlayer) return false;
        for(var vehicle:IsoWorld.instance.currentCell.getVehicles())
            if(Math.abs(vehicle.getX()-(x+0.5))<3 && Math.abs(vehicle.getY()-(y+0.5))<5) return false;
        if(zombieRadius>0) for(IsoZombie zombie:IsoWorld.instance.currentCell.getZombieList()) {
            double dx=zombie.getX()-(x+0.5),dy=zombie.getY()-(y+0.5);
            if((int)Math.floor(zombie.getZ())==z && dx*dx+dy*dy<=zombieRadius*zombieRadius) return false;
        }
        return true;
    }
    private static boolean reachable(int ox,int oy,int tx,int ty,int z) {
        if(ox==tx && oy==ty) return true;
        IsoGridSquare origin=square(ox,oy,z);
        // A demolished origin has no safe adjacency interpretation.
        if(origin==null || !origin.TreatAsSolidFloor()) return false;
        ArrayDeque<int[]> queue=new ArrayDeque<>();Set<Long> seen=new HashSet<>();
        queue.add(new int[]{ox,oy});seen.add(((long)ox<<32)^(oy&0xffffffffL));
        int[][] directions={{1,0},{-1,0},{0,1},{0,-1}};
        while(!queue.isEmpty()) {
            int[] p=queue.remove();IsoGridSquare a=square(p[0],p[1],z);
            for(int[] d:directions) {
                int x=p[0]+d[0],y=p[1]+d[1];
                if(Math.abs(x-ox)>15 || Math.abs(y-oy)>15) continue;
                long key=((long)x<<32)^(y&0xffffffffL);if(!seen.add(key)) continue;
                IsoGridSquare b=square(x,y,z);
                if(b==null || !b.TreatAsSolidFloor() || !b.isFree(false) || a.isBlockedTo(b) || a.isSomethingTo(b)) continue;
                if(x==tx && y==ty) return true;
                queue.add(new int[]{x,y});
            }
        }
        return false;
    }
}
