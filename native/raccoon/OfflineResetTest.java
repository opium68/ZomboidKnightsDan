package raccoon;

import java.nio.file.*;
import java.sql.*;

public final class OfflineResetTest {
    public static void main(String[] args)throws Exception{
        Path root=Path.of(args[0]).toAbsolutePath().normalize();
        if(!root.getFileName().toString().startsWith("rce-reset-fixture-"))throw new IllegalArgumentException("Fixture directory required");
        if(Files.exists(root))throw new IllegalArgumentException("Use a fresh fixture");
        Path world=root.resolve("Saves/Multiplayer/rce_fixture");Files.createDirectories(world.resolve("map/1216"));
        Files.createDirectories(world.resolve("map/100"));Files.createDirectories(world.resolve("zpop"));Files.createDirectories(root.resolve("Lua"));
        Path inside=world.resolve("map/1216/1216.bin"),outside=world.resolve("map/100/100.bin");
        Files.writeString(inside,"inside mutation");Files.writeString(outside,"outside must survive");
        Files.writeString(world.resolve("zpop/zpop_38_38.bin"),"zombies");
        Files.writeString(world.resolve("global_mod_data.bin"),"never delete global data");
        Class.forName("org.sqlite.JDBC");
        try(Connection c=DriverManager.getConnection("jdbc:sqlite:"+world.resolve("players.db"));Statement s=c.createStatement()){
            s.execute("CREATE TABLE networkPlayers(id INTEGER,world TEXT,x REAL,y REAL,z REAL,isDead INTEGER)");
            s.execute("INSERT INTO networkPlayers VALUES(1,'legacy-world-id',10000,10000,0,0)");
        }
        try(Connection c=DriverManager.getConnection("jdbc:sqlite:"+world.resolve("vehicles.db"));Statement s=c.createStatement()){
            s.execute("CREATE TABLE vehicles(id INTEGER,x REAL,y REAL)");
            s.execute("INSERT INTO vehicles VALUES(1,10000,10000),(2,1000,1000)");
        }
        String checkpoint="version=1\nworld=rce_fixture\ncycle=1\nstartedHour=0\ncurrentHour=0\nregistryOccupants=0\nsavedAt=100\n";
        Files.writeString(root.resolve("Lua/RCE-rce_fixture-checkpoint.txt"),checkpoint);
        OfflineReset.main(new String[]{root.toString(),"rce_fixture","inspect"});
        if(!Files.exists(inside))throw new AssertionError("Inspection mutated world");
        Files.writeString(root.resolve("RCE-rce_fixture-clean-stop.properties"),"savedAt=100\n");
        OfflineReset.main(new String[]{root.toString(),"rce_fixture","apply"});
        if(!Files.exists(inside))throw new AssertionError("Offline living occupant did not block reset");
        try(Connection c=DriverManager.getConnection("jdbc:sqlite:"+world.resolve("players.db"));Statement s=c.createStatement()){
            s.execute("UPDATE networkPlayers SET isDead=1");
        }
        Files.writeString(root.resolve("Lua/RCE-rce_fixture-checkpoint.txt"),checkpoint.replace("registryOccupants=0","registryOccupants=1"));
        OfflineReset.main(new String[]{root.toString(),"rce_fixture","apply"});
        if(!Files.exists(inside))throw new AssertionError("Registry occupant did not block reset");
        Files.writeString(root.resolve("Lua/RCE-rce_fixture-checkpoint.txt"),checkpoint);
        // Missing/stale/malformed receipts must leave EVERY world byte alone.
        Path clean=root.resolve("RCE-rce_fixture-clean-stop.properties");
        java.util.Map<Path,byte[]> before=new java.util.HashMap<>();
        try(var walk=Files.walk(world)){
            for(Path file:walk.filter(Files::isRegularFile).toList())before.put(file,Files.readAllBytes(file));
        }
        Files.delete(clean);
        for(String receipt:new String[]{null,"savedAt=99\n","savedAt=\\uZZZZ\n"}){
            if(receipt!=null)Files.writeString(clean,receipt);
            OfflineReset.main(new String[]{root.toString(),"rce_fixture","apply"});
            for(var entry:before.entrySet()){
                if(!Files.isRegularFile(entry.getKey()) || !java.util.Arrays.equals(entry.getValue(),Files.readAllBytes(entry.getKey())))
                    throw new AssertionError("Deferred startup changed world: "+entry.getKey());
            }
            if(Files.exists(root.resolve("RCE-backups")) || Files.exists(root.resolve("Lua/RCE-rce_fixture-reset.txt")))
                throw new AssertionError("Deferred reset wrote artifacts");
            if(!Files.readString(root.resolve("Lua/RCE-rce_fixture-checkpoint.txt")).equals(checkpoint))
                throw new AssertionError("Deferred reset rewrote checkpoint");
        }
        Files.writeString(clean,"savedAt=100\n");
        OfflineReset.main(new String[]{root.toString(),"rce_fixture","apply"});
        if(Files.exists(inside) || Files.exists(world.resolve("zpop/zpop_38_38.bin")))throw new AssertionError("Region was not removed");
        if(!Files.readString(outside).equals("outside must survive"))throw new AssertionError("Mainland changed");
        if(!Files.exists(world.resolve("global_mod_data.bin")))throw new AssertionError("Global data deleted");
        if(!Files.exists(root.resolve("Lua/RCE-rce_fixture-reset.txt")))throw new AssertionError("Cycle instruction missing");
        try(Connection c=DriverManager.getConnection("jdbc:sqlite:"+world.resolve("vehicles.db"));Statement s=c.createStatement();ResultSet r=s.executeQuery("SELECT id FROM vehicles")){
            if(!r.next() || r.getInt(1)!=2 || r.next())throw new AssertionError("Vehicle scope mismatch");
        }
        System.out.println("RCE_RESET_FIXTURE_PASS missing/stale/malformed receipt defers without changing world; offline living blocks; dead does not; scoped files/vehicles; verified backup; global/mainland preserved");
    }
}
