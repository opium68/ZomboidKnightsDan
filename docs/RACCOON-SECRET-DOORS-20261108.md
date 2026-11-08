# Interactive secret passages — 2026-11-08

## Final rules

Candidate 0.1.0-20261108.5 is queued for the next normal host start. Each of four sites independently selects whether its **비밀문 개방** button exists, with probability 50% per expedition cycle. Zero to four buttons is possible; there is no guaranteed total of two. Choices are persisted server-side, survive re-entry/restart within a cycle, and reroll only on a new cycle. The server enforces the same eligibility as the client menu.

| Site | Furniture coordinate |
| --- | --- |
| School principal room | 10409,9999,2 |
| Northeast gun-store ground-floor secret room | 10315,9960,0 |
| Slaughterhouse ground-floor entry | 10122,10404,0 |
| Slaughterhouse underground room | 10119,10410,-1 |

Detection uses the exact coordinate and real container/moveable furniture properties, so the player may change cabinet models. All connected pieces of a multi-square cabinet are checked and removed together. Any contents in any piece disable opening; the server rechecks this to protect stored items. Living nearby players on the same floor and outside a vehicle may use the button; administrator permission is not required. The server also checks the current object index and sprite and rejects stale/spoofed requests. Removal uses the native replicated object-removal path and refreshes collisions. Each site's opening state is independent.

Only furniture with a selected, unopened button gives the clue: staying within three tiles for one second displays **뭔가 수상하다** above the local character for two real seconds. It does not continuously retrigger while the player stays nearby; moving more than five tiles away re-arms the clue. Each client polls a small public status containing only cycle/door flags, never the account-growth registry. The overlay uses per-player screen/zoom offsets. Actual multiplayer HUD appearance and simultaneous two-client observation still need a play check.

**Ordinary demolition, destruction and pickup remain allowed**, explicitly selected by the owner. Consequently a missing button is a missing interaction clue, not an absolute lock against physical entry. Manually removed furniture is not replenished in the same cycle.

## Structural preparation and reset

The server preloads the sites for initial preparation, then removes only these exact original structural sprite/coordinate pairs:

- School: west wall 10408,9999,2 (location_business_bank_01_0), plus eight iron-bar pieces x10404–10407 / y9998–9999 / z2 (location_community_police_01_0).
- Gun store: north wall 10315,9959,0 (industry_trucks_01_5), plus ten iron-bar pieces x10313 and10315 / y9954–9958 / z0 (location_community_police_01_0).

No iron-bar door is added. This is the final replacement for the briefly proposed door. Floors and unrelated walls remain. Current player-placed furniture is kept. Fresh cycles move the original school bookshelf and gun-store shelving to their interaction positions with connected furniture and contents preserved. If an old blocker and a different player cabinet both exist, the old furniture is relocated intact to a free neighboring footprint. If no original furniture exists, an empty bookshelf provides the interaction furniture. A reset uses original/default furniture, not a snapshot of an arbitrary player-built model. Opening one site does not open another.

## Additional basement ampoules

The gun-store basement room containing 10318,9960,-1 (gunstorestorage, x10316–10323/y9956–9962/z-1) independently receives **0–3 ampoules total per cycle** across its actual storage containers. Identically named rooms elsewhere are excluded; stacked duplicate tile records are deduplicated. Existing 3–5 principal-room and 3–5 slaughterhouse-room quotas remain. A same-cycle upgrade adds only the new basement allocation, preserving the older plans and delivery ledgers, including a saved zero allocation.

## Verification

The complete expedition regression suite passes, including four independent persisted 50% choices, menu/server agreement, exact one-second dwell/two-second render deadline, replay/spoof/nonempty rejection, multi-square movement/deletion, new-cycle preparation and same-cycle loot migration. Signed updater install/rollback and unrelated-mod preservation pass for .5.

Native B42 inspection of copied map chunks confirms both school and gun-store ground-floor paths are continuously clear in both directions after the furniture interaction, and native fallback cabinets have usable empty containers next cycle. The probe fixture initially emptied only one half of a shelf and was correctly rejected; the corrected full-footprint fixture passes. Current player-placed furniture and the two newly nominated slaughterhouse objects still need an ordinary-client play check after rollout.

## Deferred rollout

The owner selected application at the **next server start**. The signed .5 package is uploaded as a GitHub draft, while the active client manifest stays on .3. Normal one-click hosting performs its existing backup and deployment first, then validates the queued signed manifest/archive and all installed owned-mod hashes, activates the Git release, and starts the server. A running port, changed manifest, bad signature or mismatched installed file prevents activation/start; the queue remains for retry. Successful activation archives the instruction once.

Both PowerShell 7 and Windows PowerShell 5 isolated gate tests cover check-only/no side effects, running-server refusal, mismatched server files, invalid signatures, successful matching stopped-server activation and one-time queue consumption. The test publisher is a local stub: these tests publish nothing and touch no operating save. No live world edits, runtime injection, server shutdown or client update were performed during this work. Clients close the game and run JOIN-SERVER.cmd after the next host start.
