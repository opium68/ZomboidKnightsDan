# November fixes - 2026-11-08

Version 0.1.0-20261108.2.

## Medical ampoules

Each of the eleven reviewed buildings independently receives 0, 1, 2 or 3 additional growth ampoules per expedition cycle. Multiple medical rooms in the same building share one quota. Total additional supply ranges from 0 to 33; the existing primary pool and ordinary 1% bonus remain separate. Targets are medical-room cabinets/shelves/counters; police infirmary uses its side cabinet, not badge boxes. Actual medicine cabinets are preferred where present. Persistent per-building plans and per-container delivered counts prevent rerolls and repeat-entry duplication; a new cycle resets the supplemental ledger.

The six clinic-bearing buildings plus five medical/medicaloffice/medicalstorage facilities are keyed by the reviewed map building IDs: 38_38/0, 38_39/17, 38_39/3, 38_40/8, 39_38/0, 39_38/5, 39_39/18, 39_40/10, 39_40/8, 40_39/16, 40_40/1.

## RPD passages and music

The obstructing shelf at 10221,10410,0 is relocated to the adjacent vacant tile 10221,10409,0, retaining its inventory. The other reported square, 10217,10401,0, was already empty in both the static container data and the saved runtime objects; its local collision state is refreshed instead of deleting unrelated walls. Both exact squares passed native free-square checks after repair. The repair retries while unloaded/occupied and applies to regenerated map chunks. Real client movement still requires a play check.

Only the ResidentEvilPolice playback instance is set to volume multiplier 0.3. Other sound instances are unchanged.

## Hydration backpacks

Native engine tests of ordinary and mythic hydration packs confirmed direct fluid consumption reduces water and thirst. A targeted shared timed-action correction binds hydration actions to the actual resolved inventory item's fluid component and initializes consumption from that component, addressing detached/stale action references without replacing the ordinary server-authoritative drink action. Focused regression covers stale empty references, partial and full consumption, repeated callbacks and ordinary bottle passthrough. Actual multiplayer drinking must be checked after client update; the original report was not fully reproduced across a live client/server action.

## Local account maintenance

The requested account-specific respec was handled separately through a validated offline player transaction. Item-preservation, native save/reload and other-player row comparisons were recorded in private local maintenance logs. Personal mutation helpers and character data are absent from the release.

## Verification and deployment

Before work, standalone verified full backup escape_test-20261108-121517.zip was created: 278901311 bytes, 249550 entries; SHA256 E11907F94665C7369D20B6C4572B76827B8694D027F29BE8C08520201B7F1ACC. Existing expedition regressions and focused medical/hydration tests pass. The operating server was kept loopback-only for maintenance, the current expedition cycle was preserved, and normal shutdown/receipt was verified. PauseEmpty was restored. All ten engine anti-cheat categories remain configured at 4 (disabled).

The server is left stopped. Start through the usual host launcher; clients fully close the game and run JOIN-SERVER.cmd for the signed Git update. Workshop originals remain Steam dependencies. No automatic full-world or character reset was introduced.
## Loot multiplier adjustment

At the owner's request, RangedWeaponLootNew remains 1.2 and AmmoLootNew changes from 4.0 to 2.0 in both the operating and host-deployment SandboxVars. The original configuration files were backed up locally. The server remains stopped; the next normal startup uses these values for new loot generation. Already generated container inventories are not reduced or rerolled by this setting change.

## Secret-room reward update

Release 0.1.0-20261108.3 adds an independent 3–5 ampoules per cycle to each of the principal and slaughterhouse secret rooms, and replaces original dabaojian rewards with one ampoule per sword. Entry-route inspection found no ordinary doorway to the principal or gun-store hidden rooms; the slaughterhouse basement stairs passed bidirectional native collision checks. See [secret rewards and entry findings](RACCOON-SECRET-LOOT-20261108.md). No entrance walls were changed.

## Queued interactive passages

The .5 candidate is prepared for the next normal server start: four independent 50% cabinet buttons, one-second proximity/two-second overhead clue, original school and gun-store iron bars removed, and a separate 0–3 ampoules in the northeast gun-store basement. Ordinary demolition remains allowed. This is deferred deployment, not a live .5 activation. See [the final rules and rollout checks](RACCOON-SECRET-DOORS-20261108.md).
