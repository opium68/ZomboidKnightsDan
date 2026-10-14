# Contract reward multiplier

Current deployment (0.1.0-20261014.6): contract money is 3x the original amount (30% of the previous 10x rate). Shop prices, item-sale proceeds and stocks are unchanged. Existing unfinished 10x records migrate by reward / previous marker * 3; unmarked records use the original baseline. Board notes and new missions use 3x; kill bonuses are 15 per kill including the native 5. Completed/cancelled records, bank balances and already queued cooperative payout receipts are preserved.

Kahlua PASS: 750 -> 2250; full kill mission 1750 -> 5250; cooperative 5025 -> 15075 per member; solo 1000 + three kills -> 3045. Existing 17500 / marker 10 -> 5250 / marker 3; repeated migration and old 10x board mission generation do not rescale twice.

Applied with daily fixed Buy Goods after game/server shutdown. Native B42.21 migration and repeat-safety, existing clothing/market regressions, isolated boot/save/normal quit, PS5.1 signed updater/rollback PASS; all 73 live owned hashes match. Backup: backups/owned-mods-before-0.1.0-20261014.6. In-game multiplayer display/payout confirmation remains pending. Public deployment evidence is recorded in KNIGHTS-MARKET-20261014.md.

## Historical 10x deployment (2026-10-12)

Deployed release: 0.1.0-20261012.2. Multiply contract money by ten; shop prices, item-sale proceeds and stocks are unchanged.

Board offers and mission rewards show tenfold amounts. Mission scaling occurs after native location, requested-item and zombie-target modifiers. When a board offer is already scaled, mission generation receives a copy with its original base value, so a kill objective's extra reward is also tenfold without double scaling the base. Notes use the scaled reward.

Uncompleted world contracts migrate once, using a persistent knightsRewardMultiplier marker. Completed/cancelled records and previously queued cooperative receipts are preserved. Native contract creation may transmit before returning; migration is suppressed during creation and the new record is marked before transmitting again. Repeated world lookups do not multiply rewards again.

Cooperative payout uses the scaled reward plus fifty per recorded kill. Native solo completion receives the remaining forty-five per kill before its existing five-per-kill addition; failure restores the prior player reward. Native bank credit, receipt creation and completion guards remain in place. Legacy solo state without a world record scales its original reward at completion. Existing contract notes on inventory paper may need a normal contract synchronization to refresh.

Tests with actual PZLinux source and Kahlua pass: board 750 becomes 7500; a ten-zombie mission becomes 17500 (original 1750); existing cooperative fixture 5025 becomes 50250 for each registered character, including deferred offline payout. Solo 1000 plus three kills becomes 10150. Legacy migration, native creation/transmit, completion receipts and duplicate-completion guards pass. Daily refresh/expiry and accepted-record preservation regression passes. Actual in-game display/payout verification is pending.

Applied after checking server/game were stopped. All 61 owned mod files match the signed release. PowerShell 5.1 updater validation/install/no-op/rollback tests pass; signed public release and archive verified. Backup: backups/owned-mods-before-0.1.0-20261012.2. GitHub source 0dd2e5b; activation 9e5664b. No additional clothing mods or daily-purchase behavior changes are installed in this release.

## Historical Buy Goods review (superseded by .6 daily offer implementation)

Installed client Context/World/Features/PZLinuxRequest.lua rolls package count, items, vehicle and vehicle delivery location inside onContractId on every conversation. Daily category availability does not persist those rolls. A daily authoritative offer store would persist category contents, quantities, vehicle, price and location under the game-calendar date; purchase requests would reference its ID and server validation would reject arbitrary client substitutions. The offer remains stable on reconnect/restart until the next game midnight. Retain current purchase/category limits. User requested feasibility separately; daily purchase locking is not implemented in this release.
