# Raccoon secret-room rewards — 2026-11-08

## Rules

Each expedition cycle independently selects 3–5 extra RPGSkillTree.LevelUpElixir for the school principal secret room (DeanSecureRoom), and another 3–5 for the slaughterhouse basement secret room (secretslaughter). Counts are totals per room, not per container. Principal rewards use the two crates at 10401,9998–9999,2; basement rewards use the three metal shelves at 10110,10411–10413,-1. Existing room rewards remain. These additions are separate from primary 8–12 ampoules, medical-building 0–3, 1% bonus containers and vaccine zombies.

The server persists its random plan and delivery ledger under RaccoonExpedition.secret, keyed to the expedition cycle. Re-entry, normal chunk loading and restart within the same cycle do not reroll or replenish collected grants. Unloaded containers receive pending grants when their chunks load. The normal empty-on-restart policy still controls the next cycle.

Every original dabaojian reward slot in both map distribution tables and the OnFillContainer callback now produces one growth ampoule instead. Original chances, caps and DisableDaBaoJian guards remain. The upstream sword-shop nested item/weight pair is corrected to the required flat array. Already generated Base.dabaojian items in loaded Raccoon City world containers are converted one-for-one, preserving other contents; creation failure keeps the sword. Gun-store reward squares are also checked periodically. Character inventories are not rewritten. Item definitions remain available for save compatibility.

## Entry-route inspection

The installed map was parsed and a copied operating-save region was loaded in an isolated B42 server. No operating map objects were changed by this inspection.

| Location | Coordinates | Finding |
| --- | --- | --- |
| Principal secret room, floor 3 | x10401–10407, y9998–9999, z2 | All 18 perimeter transitions collide in both directions. No ordinary doorway or direct walk-in entrance was found. Ordinary bank/police wall sprites surround it; no dedicated unlock handler was found. Wall demolition itself has not been tested. |
| Northeast gun-store hidden room, floor 1 | x10307–10316, y9954–9958, z0 | All 30 perimeter transitions collide in both directions. No ordinary doorway or dedicated unlock handler was found. An entrance would require opening a wall; no new entrance has been created. |
| Slaughterhouse secret basement | x10110–10120, y10405–10415, z-1 (irregular room) | North-facing stairs at 10120,10405–10407,-1 lead to surface landing 10120,10404,0. Native up/down collision checks both return false, and the landing reports a staircase floor. The underground ordinary door is at 10117,10409,-1. Actual client walking through the complete building remains to be checked. |

The mod's exterior-only barrier protection does not cover these interior walls. This inspection did not add a door, remove a wall or change the puzzles.

## Validation and rollout

Release 0.1.0-20261108.3. Focused Lua regression covers exact independent 3/4/5 totals, repeat callbacks, cycle reset, one-for-one sword migration, other-item preservation and failed replacement creation. The existing expedition regressions, Lua syntax/JSON/override-manifest checks and signed updater installation/rollback tests pass. Isolated native boot creates the secret plan without a SecretLoot exception; route inspection passes. SpriteConfig asset warnings are present in the upstream test environment and are not treated as proof of a new Lua error.

The operating server is left stopped; installed mod files take effect on its next normal startup. Clients fully close the game and run JOIN-SERVER.cmd to update from Git. Workshop originals remain Steam dependencies. No world reset or character respec is performed by this update.

Pre-update standalone backup: escape_test-20261108-175720.zip, 278883717 bytes, 249549 entries, SHA256 560DF6C2833BEF2F889A98FBC61618EA1AA21240E491ACE29B6CCB395D21B40B. Installed RCE files were verified against the tested stage by SHA256. The operating save and current cycle were not opened or changed by this deployment.

## Subsequent entrance and loot work

The original no-doorway findings above predate the queued .5 candidate: four interactive furniture sites independently select buttons at 50% each, the original school and gun-store inner walls/bars are cleared, and the gun-store basement containing 10318,9960,-1 gains a separate 0–3 ampoules. Principal and slaughterhouse totals remain 3–5 each. Ordinary demolition remains allowed. See [final rules and deferred rollout](RACCOON-SECRET-DOORS-20261108.md). The active manifest stays on .3 until the next normal host start.
