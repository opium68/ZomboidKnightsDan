# RPD secret armory and stairwell repair - 2026-11-08

Version: 0.1.0-20261108.1.

Players reported that completing the badge mechanism created the upper staircase, but the secret armory remained closed and the staircase could not be descended. An isolated engine loaded 25 copied operating-save chunks and confirmed all six puzzle stairs existed while all six original upper floor blockers and the armory wall remained. The former client-side sledgeDestroy path did not achieve the intended persisted removals. This was not the exterior barrier protection, whose predicate excludes this interior location.

The server now verifies all six original puzzle stairs before removing the exact secret entrance sprite d_shisan_cannotdamaged_16 at 10223,10380,3 and the exact floor sprite d_shisan_floor_01_49 at X=10231..10233, Y=10383..10384, Z=3. Changes use server object-removal propagation and refresh collision/path properties. Other walls, the landing, lower floors and stairs are preserved. The check retries once per second as loaded squares become available; it also repairs already-completed puzzles after a restart without asking for more badges. No global completion flag survives a map reset: the physical six-stair proof is required again.

Focused regression covers incomplete/unloaded stairs, client mutation refusal, exact wall removal, all six floor blockers, unrelated-object preservation, repetition and reset. Existing expedition regressions pass. On an isolated operating-save copy, both stair lanes passed native ascending and descending blockage checks after repair; all six upper floor blockers were absent and repeated repair removed nothing. Actual player movement after production restart remains to be checked.

The running operating server and its save were not modified or restarted. The normal host launcher deploys the rebuilt stage on its next startup. Clients update through the Git launcher. Workshop originals continue to come from Steam.