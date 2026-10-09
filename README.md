# Zomboid Knights Dan

Project Zomboid 42.21 server patches and automatic client launcher.

Download [KnightsDan-Launcher.zip](https://github.com/opium68/ZomboidKnightsDan/releases/latest/download/KnightsDan-Launcher.zip), extract it and run `JOIN-SERVER.cmd`. Subsequent runs obtain the server's signed release, verify SHA-256, install the owned patches together and then launch the game. The server password is supplied separately.

Original mods remain on Steam Workshop. This repository contains only our own patches, launcher files and configuration references. It contains no save, database, server password or signing credential.

Cooperative contracts: invite nearby players from the right-click menu; invited players accept the invitation before the leader accepts a computer contract. Everyone must be online and nearby at acceptance. The roster is then fixed. Progress is shared and every registered character receives the full reward once; offline receipts are settled on the next bank synchronization. Accounts and vehicle purchases remain personal.

PZLinux stock trading is enabled and buys/sells through personal bank accounts. ATM menus, cash deposit/withdrawal and new ATM refill contracts are disabled. Computer wear, repair UI and world-age price inflation remain disabled. Automatic login animation, electricity, ID-card hacking, mail and reputation remain enabled. Existing bank balances, holdings and cash items are preserved; existing ATM refill jobs can be cancelled from the computer. Selected equipment and cars are supplied through purchases/rewards; natural loot and manufacturing are blocked. Maintenance, fuel, ammunition loading and repairs remain available. M60 linking has a separate 100-round recipe.

Initial prices are editable in `config/knights-reward-prices.json`. Server startup, source checks, cooperative logic and updater rollback are tested separately from two-player equipment, NVG and turret gameplay verification.

Successful surplus-item and Dark Web sales credit the personal bank account directly. Replayed sale receipts do not credit twice. Previously created payment parcels retain their existing mailbox redemption flow. Neat Crafting list and detail views tolerate unresolved recipe skill references without changing server crafting requirements; actual ammunition unpacking remains a client gameplay check.

The shared contract board refreshes at midnight in game time with 3-5 random offers. Unaccepted offers from the previous day expire; accepted jobs remain active. Each participant can have only one active job. Boot, automatic login and general item-purchase dialogue run about five times faster while retaining their text and login animation.

Ammunition unpacking/repacking and opening purchased meal or weapon cases are permitted. Manufacturing reward equipment and food remains restricted. Restart both server and game after updating to reload recipe conditions.

Lifestyle: Hobbies is installed through Steam Workshop (3403870858). Large fluid containers can use the native drink action without the 3 L capacity restriction; sealed-container and fullness checks remain. Multiplayer musical performance and drink synchronization still require in-game verification.