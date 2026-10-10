# Zomboid Knights Dan

Project Zomboid 42.21 server patches and automatic client launcher.

Download [KnightsDan-Launcher.zip](https://github.com/opium68/ZomboidKnightsDan/releases/latest/download/KnightsDan-Launcher.zip), extract it and run `JOIN-SERVER.cmd`. Subsequent runs obtain the server's signed release, verify SHA-256, install the owned patches together and then launch the game. The server password is supplied separately.

Original mods remain on Steam Workshop. This repository contains only our own patches, launcher files and configuration references. It contains no save, database, server password or signing credential.

Cooperative contracts: invite nearby players from the right-click menu; invited players accept the invitation before the leader accepts a computer contract. Everyone must be online and nearby at acceptance. The roster is then fixed. Progress is shared and every registered character receives the full reward once; offline receipts are settled on the next bank synchronization. Accounts and vehicle purchases remain personal.

PZLinux stock trading is enabled and buys/sells through personal bank accounts. ATM menus, cash deposit/withdrawal and new ATM refill contracts are disabled. Computer wear, repair UI and world-age price inflation remain disabled. Automatic login animation, electricity, ID-card hacking, mail and reputation remain enabled. Existing bank balances, holdings and cash items are preserved; existing ATM refill jobs can be cancelled from the computer. Selected equipment and cars are supplied through purchases/rewards; natural loot and manufacturing are blocked. Maintenance, fuel, ammunition loading and repairs remain available. M60 linking has a separate 100-round recipe.

Initial prices are editable in `config/knights-reward-prices.json`. Server startup, source checks, cooperative logic and updater rollback are tested separately from two-player equipment, NVG and turret gameplay verification.

Successful surplus-item and Dark Web sales credit the personal bank account directly. Replayed sale receipts do not credit twice. Previously created payment parcels retain their existing mailbox redemption flow. Neat Crafting list and detail views tolerate unresolved recipe skill references without changing server crafting requirements; actual ammunition unpacking remains a client gameplay check.

The shared contract board refreshes at midnight in game time with 3-5 random offers. Unaccepted offers from the previous day expire; accepted jobs remain active. Each participant can have only one active job. Boot and all common PZLinux dialogue/typing, including contracts, login and purchases, run about five times faster while retaining their text and login animation. The multiplier is applied once; existing fast login and purchase dialogue do not become 25 times faster.

Ammunition unpacking/repacking and opening purchased meal or weapon cases are permitted. Manufacturing reward equipment and food remains restricted. Restart both server and game after updating to reload recipe conditions.

Lifestyle: Hobbies is installed through Steam Workshop (3403870858). Large fluid containers can use the native drink action without the 3 L capacity restriction; sealed-container and fullness checks remain. Multiplayer musical performance and drink synchronization still require in-game verification.

The vanilla fishing panel uses the Korean bitmap font in Korean-language games to avoid question-mark substitutions in its SDF font. Panel and fish-tooltip text retain native translation and discovery rules; visual gameplay verification remains separate from automated checks.

When a backpack's Bedroll attachment slot disappears, automatic detachment now synchronizes the tool's attachment fields with the multiplayer server. The tool remains in the character inventory. Actual backpack pickup and rewearing still require multiplayer verification; native weight limits remain.

The cooperative manhunt guard no longer calls a private native resolver as a global function. Successful decapitation uses the original evidence-bag creation path while retaining participant checks. In-game evidence delivery remains separate from automated native-Lua regression tests.

Humvee VRO welding repairs use the normal vehicle-maintenance pose as a candidate workaround for reported animation-blend overflow. Materials and repair completion logic are retained. Actual FPS improvement and renderer stability still require in-game verification.