# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v3.5.0]

### 🛠️ Compatibility & Cross-Mod Safety
- [Bugfix] **Vault-Only Install Crash (cosmicvaulteconomy.lua):** `include("cosmicwarbridge")` was unguarded at module load. Cosmic Vault has no dependency on Cosmic War in `modinfo.lua`, so any install running Vault without War (or Vault + Overhaul only) would throw `module not found` and take down the entire economy library the moment anything included it. Now soft-included via `pcall`, matching Vault's actual role as the standalone foundational dependency.
- [Bugfix] **Config Menu Crash on Missing Sister Mods (cosmicconfigmenu.lua):** `initialize()`/`fillTree()` unconditionally `include()`d `cosmicoverhaulconfig`, `cosmicwarconfig`, and `cosmicascendancyconfig`. Same failure mode as above — any install missing one of those three sister mods would crash the CCM UI outright. All four sister-config includes are now wrapped in `pcall` via a shared `loadSisterConfigs()` helper.
- [Bugfix] **Famine Relief Cache Hard-Dependency on Chronicles (economyupdater.lua):** `EconomyUpdater.updateServer`'s Famine Relief Cache spawner unconditionally called `beacon:addScriptOnce("data/scripts/entity/cc_blackbox.lua")` — a file that only exists in Cosmic Chronicles. Vault declares zero dependencies, so any install without Chronicles (e.g. Vault + Starfall) would fail this attach every time a sector's controlling faction hit Famine Score 100+. Now wrapped in `pcall` so the beacon still spawns correctly without Chronicles installed.

### 🪲 Bug Fixes
- [Bugfix] **Permanent Buffs Could Never Be Removed (cosmicvaultbuffs.lua):** `removePermanentFactor`/`removePermanentBaseMultiplier` called `entity:removeMultiplyableBias`/`entity:removeBaseMultiplier` — neither method exists in the engine (only the universal `entity:removeBonus(key)` does), and the corresponding `apply*`/`add*` functions discarded the bonus `key` the engine returns, so there was nothing to pass to `removeBonus` even after fixing the method name. Removal now silently failed every time, and reapplying a factor would stack indefinitely. Added per-entity/per-stat key tracking (in-memory only — bonus handles reset on server restart anyway) so add/remove/re-apply is now idempotent and actually works.
- [Bugfix] **`clearBuffs` Deferred-Removal Hang Risk (cosmicvaultbuffs.lua):** Used `while entity:hasScript(...) do entity:removeScript(...) end` bounded by a manual safety counter. `removeScript` is deferred, so `hasScript` never reflects the removal within the same tick — the loop always ran its full 100 iterations regardless of how many buff scripts were actually present. Replaced with a single snapshot of `entity:getScripts()` and one `removeScript(index)` call per matching entry.
- [Bugfix] **Escort Orders Had No Target (cosmicvaultfleet.lua):** `orderEscort` passed `target.index.string` (a plain Lua string) to `OrderChain.addEscortOrder`, which internally calls `.string` on its `craftId` argument expecting a `Uuid` object. Indexing `.string` on a plain string resolves through Lua's `string` library metatable and returns `nil`, so the resulting order's `craftId` was always `nil` — ships would accept the Escort order but never actually track a target. Now passes `target.index` (the raw `Uuid`).
- [Bugfix] **Custom Loot Always Dropped Zero Units (cosmicvaultloot.lua):** `dropCustomLoot` called `Sector:dropCargo/dropTurret/dropUpgrade(position, reservedFor, deniedFor, ...)` with a raw faction-index integer (or `0`) in the `reservedFor`/`deniedFor` slots, which strictly expect `nil | Faction`. For the `"good"` branch specifically, `amount` and the literal `0` were also swapped into the wrong positional slots (`owner`/`amount`), so every custom good drop actually requested `0` units regardless of what the caller asked for. Fixed the argument order and now wraps `owner` in `Faction(owner)` for the reservation slots.
- [Bugfix] **Generated Turrets Ignored Rarity/Material (cosmicvaultarsenal.lua):** `GenerateTurret` wrote `config.rarity`/`config.material` to `turret.rarity`/`turret.material` — both are **read-only** on `InventoryTurret`, so the C++ engine silently discarded every write. Moved both onto the `Weapon` object instead, where `rarity`/`material` are genuinely writable. Also removed a no-op `turret.weaponName = config.weaponType` line (also read-only) and fixed the `Weapon(config.weaponType)` call, which was passing an argument to a constructor that vanilla always calls with zero arguments (the argument was silently discarded either way). **Known limitation, not fixed:** `config.weaponType` still has no effect on the generated weapon's actual damage-type/behavior — real per-type weapon generation requires manually configuring physics fields (`setProjectile()`/`setBeam()`, `fireDelay`, `pvelocity`, etc. per vanilla's `weapongenerator.lua`), which this helper does not implement. Documented inline rather than guessed at.
- [Bugfix] **Client Crash Risk in Progression/Settings APIs (cosmicvaultplayersettings.lua, cosmicvaultprogression.lua):** `CosmicVaultPlayerSettings.get/set` and `CosmicVaultProgression.getXP/hasPerk` called `Player():getValue()`/`setValue()` with no `onServer()` guard. Those are server-only engine APIs — calling them from any client-side script (e.g. a HUD widget built on top of these APIs) crashes with `invalid userobject of type Player`. All four now bail out safely on the client.
- [Bugfix] **Cinematic Banner/Popup Could Fail to Attach (cosmicvaultui.lua):** The fallback `player:addScriptOnce("cosmicvaultcinematic.lua")` (run only if the player is somehow missing the script) used a bare filename. Unlike `invokeFunction`/`hasScript`, `addScriptOnce` requires the full `data/scripts/...` path to resolve via the VFS and silently fails to attach otherwise. Fixed across all three call sites.
- [Bugfix] **Solar Flare Resistance Check Crashed (cosmicvaultweatherdictionary.lua):** `isShipPrepared` read `block.volume` on a `BlockPlanBlock`, a property that does not exist on that object (confirmed against `Avorion_Mega_Stub.lua`) — reading an undefined property on engine userdata throws a fatal `Property not found or not readable` exception, not a silent `nil`. Any ship with Trinium-or-above blocks would crash the weather tick the first time this ran. Volume is now correctly derived from `block.box.size`.
- [Bugfix] **Stat Buffs Applied Inverted Values (cosmicbuff.lua):** `CosmicVaultBuffs.applyBuff` is documented as taking a scale factor ("0.5 for half speed, 2.0 for double damage"), but the implementation passed that value directly into `entity:addBaseMultiplier`, which takes an **additive delta** (`Final = Base * (1 + delta)`). A caller following the documented contract and passing `0.5` for "half speed" was actually granting a +50% speed **boost**; `2.0` for "double damage" granted +200% instead of +100%. Now converts to `multiplier - 1.0` before applying, so the documented contract is what actually happens.
- [Bugfix] **Solar Flare Damage Completely Broken (cv_weather_controller.lua):** Read `entity.shieldMax`, a property that does not exist (the real property is `shieldMaxDurability`) — same fatal-read crash class as above. Also called `entity:inflictDamage(damage, damageSource, damageType, index, location, inflictorId)` with a `vec3` (the entity's own position) in the `index` slot and a `Uuid` (the entity's own id) in the `location` slot, with `inflictorId` omitted entirely. Fixed both the property name and the full argument list (block `index = 0`, `location = vec3()`, matching vanilla's own whole-ship-hit convention).
- [Bugfix] **Potential nil-Crash in Sector Defender Scaling (cosmicvaultscaling.lua):** `calculateSectorDefenderStrength` called `galaxy:getFactionRelations(Faction(invaderFactionIndex), Faction(entity.factionIndex))` without checking either `Faction()` call for `nil` — passing `nil` into that engine call crashes. Both sides are now guarded, and the redundant repeated `Faction(invaderFactionIndex)` construction inside the loop was hoisted out.
- [Bugfix] **Dead Duplicate RNG Draw (cosmicvaultriftescalation_server.lua):** `attackType` was assigned from `random():getInt(1, 3)` and then immediately overwritten by `random():getInt(0, 2)` on the very next line, wasting an RNG draw for no effect. Removed the dead first assignment.
- [Bugfix] **Custom Faction Traits Never Rendered (diplomacy.lua):** The shim hooked `Diplomacy.updateFactionInformation` — a function name that does not exist anywhere in vanilla `diplomacy.lua`. The real function that builds the traits text field is `Diplomacy:updateTraits(faction)`; hooking the wrong name meant the entire Custom Faction Traits feature (`CosmicVaultFaction.registerCustomTrait`/`setTrait`) has never actually appeared in the diplomacy window on any version. Re-pointed the shim at `updateTraits(faction)`, which also lets it use the `faction` parameter directly instead of re-deriving it from `factionListBox`/`self.factions` state.
- [Bugfix] **Weather Sector Warnings Never Rendered (cv_weather_ui.lua):** `updateSectorProblem` called `addSectorProblem()`/`removeSectorProblem()` — neither function exists anywhere in the engine (confirmed against the full API stub set and vanilla source); the only real, analogous mechanism is the ship-level `addShipProblem(type, shipUuid, text, icon, color)`/`removeShipProblem(type, shipUuid)` pair used by vanilla's own `badcargoshipproblem.lua`. Every weather activation near a player would throw `attempt to call a nil value` the instant this ran. Rewired to target the player's current craft via `addShipProblem`/`removeShipProblem` under a constant problem-type key.
- [Bugfix] **Nonexistent Chat-Focus Guard (ccm.lua):** Hotkey polling was gated behind `if checkInputFocus and checkInputFocus() then return false end` — `checkInputFocus()` does not exist anywhere in the engine, so the guard was permanently a no-op and hotkeys never actually respected chat/text-input focus despite being documented as doing so. Replaced with a real Enter-toggles/Escape-closes/cursor-visibility-fallback heuristic (the same verified approach used by the reference Mod Configuration Menu), installed lazily on first hotkey poll via `Player():registerCallback("onPostRenderHud"/"onGalaxyMapUpdate", ...)`.
- [Bugfix] **Territory Flip Queue Corruption (cosmicvaultterritory_server.lua):** `flipSectorTerritory` — the entry point Cosmic War invokes via `invokeFunction` when a siege resolves — queued the pending flip as a Lua **table** in `Server():setValue("CosmicVault_PendingFlips", ...)`. `Server():setValue()` only supports bool/number/string/nil, and every actual reader (`CosmicVaultTerritory.resolveSiege`, `cv_territory_injector_persistent.lua`) treats that key as a `"x__y__factionIndex,"` **string** queue. Whichever side wrote last corrupted the key for the other — table writes crashed `resolveSiege`'s `string.find`, and string writes were silently discarded by the table-typed reader — so externally-triggered territory flips never actually applied. `flipSectorTerritory` now delegates to `CosmicVaultTerritory.resolveSiege`, the shared, correctly-formatted implementation.
- [Bugfix] **Custom Ship/Station Spawner Crashes (cosmicvaultblueprint.lua):** `spawnShip`'s volume-scaling path called `plan:scale(aNumber)`, but `BlockPlan:scale()` takes a `vec3`, not a plain number — every call passing the documented `volume` parameter (including MODDER_GUIDE's own example) threw immediately. Both `spawnShip` and `spawnStation` also called `ShipUtility.addMinimumCrew(...)`, a function that does not exist anywhere in `shiputility.lua` — a guaranteed crash on every single ship/station spawned through this API. Fixed the scale call to pass `vec3(factor)`, and replaced the crew call with `ship.crew = ship.minCrew` (a real, engine-computed minimum crew for the exact plan). Also found `createTurretFromPlan` silently discarding every argument — `InventoryTurret.rarity`/`.material`/`.weaponPrefix` are all read-only and there is no `customTurretDesign` field anywhere in the engine, so it always returned a blank default turret regardless of input. Since nothing in the Cosmic series currently calls it, it now logs a clear "not implemented" error and returns `nil` instead of silently pretending to work.
- [Bugfix] **Codex Info Injection Never Fired (cosmicvaultcodex.lua):** `onCosmicCodexGatherData` called `include("player/codex/infoCv")`, a subdirectory-qualified path — `include()` only searches `data/scripts/lib/` by default, and this file never set up `package.path` the way vanilla's own subdirectory includes require (see `dlc/rift/lib/riftguardian.lua`). Every Codex data-gather request threw `module not found`, so the "What is Cosmic Vault?" info pages never got injected. Added the missing `package.path` mutation at file scope.
- [Bugfix] **`registerPriceHook` Never Actually Existed (cosmicvaulteconomy.lua):** `CosmicVaultEconomy.registerPriceHook` has been documented in MODDER_GUIDE.md (and referenced in this very changelog's v3.0.0 entry) as the way to register dynamic price hooks, and `economyupdater.lua`'s `getSupplyDemandPriceChange` has been reading the `"CVE_PriceHook_<good>"` key it's supposed to populate the entire time — but the function itself was never implemented anywhere in the file. Any mod calling it as documented got `attempt to call a nil value`. Implemented it to write the exact pipe-separated `scriptName::functionName` format the reader already expects.
- [Bugfix] **Anomaly Entity Scripts Never Actually Existed (`cosmicvaultanomalies.lua`, `data/scripts/entity/cv_anomaly_rift.lua`, `data/scripts/entity/cv_anomaly_wreck.lua`):** `CosmicVaultAnomalies.spawnAnomaly`'s `"SpatialRift"` and `"PrecursorWreck"` branches have always called `entity:addScriptOnce("data/scripts/entity/cv_anomaly_rift.lua")`/`"...cv_anomaly_wreck.lua"` — but neither file has ever existed anywhere in this codebase. v3.3.2 fixed the vec3/Matrix and `createAsteroidPlan` crashes that were preventing these anomalies from spawning at all, which only exposed the next problem: once an anomaly could actually spawn (e.g. after defeating Bottan via Cosmic Chronicles' `smuggler.lua`, or after an Eclipse Boss kill via Cosmic Ascendancy's `eclipsebossbehavior.lua`), the `addScriptOnce` call would fail with `Script '...' not found` and the spawned "Unstable Spatial Rift"/"Ancient Precursor Wreck" would sit in the sector with no attached behavior at all. Implemented both scripts, following the same vanilla-verified interaction pattern already used by `cargostash.lua` (`ScriptUI():registerInteraction` + a client→server RPC via `callable()`, resolving the interacting faction through `getInteractingFaction()` for alliance-safety): each anomaly now offers a one-time "Salvage"/"Channel" interaction that drops a scaled credit/resource reward (plus a chance at a bonus turret or system upgrade) via the same `Sector:dropBundle/dropResources/dropTurret/dropUpgrade` calls already proven elsewhere in this codebase, then removes only the interaction itself — the wreck/rift entity stays behind as a permanent landmark, matching MODDER_GUIDE.md's documented "persistent interactive POI" intent for this API.

### 🔩 Namespace / Engine-Constraint Fixes
- [Bugfix] **Weather Trigger API Was Completely Dead (cosmicvaultweather_server.lua):** This file had no `-- namespace` pragma and declared its table as `local CosmicVaultWeatherServer = {}`. Without native namespace routing, `Galaxy():invokeFunction(path, "createWeather"/"removeWeather"/"getWeatherSync", ...)` — the entire public entry point used by `cosmicvaultweather.lua`'s `triggerStorm`/`clearStorm`/`getWeatherAt` — had no way to resolve those function names at all. Added the missing `-- namespace CosmicVaultWeatherServer` pragma and made the table global, restoring the entire weather-trigger API.
- [Bugfix] **Redundant Global Wrappers Shadowing Namespaces:** Removed leftover global wrapper functions (e.g. `function initialize(...) if X.initialize then return X.initialize(...) end end`) from `cosmiccodex.lua`, `cosmicvaultnews_server.lua`, `cosmicvaultterritory_server.lua`, and `cosmicvaultfactionindex.lua`. Per the engine's namespace-routing behavior (confirmed against vanilla's own `orderchain.lua`, which has zero wrappers for any of its namespaced functions), these wrappers are pure dead weight at best and a namespace-shadowing hazard at worst.

### 🧹 Housekeeping
- [Cleanup] Removed dead `package.path = package.path .. "..."` lines from ~50 files. These configure Lua's native `require()` search path, but this codebase exclusively uses Avorion's VFS-aware `include()` — `require()` is never called anywhere in Cosmic Vault, so every one of these lines was inert.

## [v3.4.1]

### 🪲 Bug Fixes
- [Bugfix] **Territory Injector Engine Parse Error:** Fixed a critical bug where a Virtual File System data type mismatch caused the background territory injector to completely fail when trying to flip station ownership during active sieges. The script now correctly parses the serialized string from the engine API.

## [v3.4.0]

### 🛠️ Architecture & Optimization
- [Optimized] **Progressive Materialization:** Completely overhauled the `CosmicVaultTerritory` API. `expandToSector()` and `resolveSiege()` no longer forcefully execute `Galaxy():loadSector()` in the background to physically generate stations. This completely eradicates server stutters during AI faction expansion and background siege resolutions.
- [Feature] **Lazy Loading API:** Added new serialized global tracker strings (`CosmicVault_PendingExpansions` and `CosmicVault_PendingFlips`). Stations are now natively and instantly constructed during the player's hyperspace loading screen when they visit the affected sector.

## [v3.3.3]

### Fixed
- **Fleet Clash AI Scaling Bug:** Fixed a syntax error during dynamic AI Fleet battles where the backend script was checking for `Entity.isPlayer` (an invalid property) instead of `entity.playerOwned`, which caused the Fleet Clash event to fail scaling its defender strength and throw errors.
- **Combat Server Hang / Freeze:** Fixed a massive server lag spike and 30-second sector freezing caused by an invalid `Uuid` string serialization error inside `cosmicdot.lua`. When sectors unloaded and reloaded, the Damage Over Time effect would corrupt its source ID, breaking the engine's durability calculation and hanging the server thread.
- **Cosmic Buff API Nil Error:** Fixed a critical namespace error in `cosmicbuff.lua` where the script failed to `include("callable")`, causing an `attempt to call global 'callable' (a nil value)` crash when trying to register remote procedure calls.

## [v3.3.2]

### Fixed
- **Anomaly Spawning Crash:** Fixed a crash occurring during the Bottan fight and Eclipse Boss events where spatial rifts and precursor wrecks would fail to spawn. This was caused by a vec3/Matrix mismatch and a missing `createAsteroidPlan` API reference in `cosmicvaultanomalies.lua`.
- **Small tweaks & bugfixes:** Various bugfixes in some API files.

## [v3.3.1]

### 🪲 Bug Fixes
- [Bugfix] **Matrix Math Crash:** Fixed a C++ API logic exception (invalid type 'Matrix' expected 'vec3') when calculating randomized ambush spawn coordinates in `cosmicvaultencounter.lua`, preventing ambush fleets from generating correctly.

## [v3.3.0]

### ✨ Features
- [Feature] **UI Buff Tracker:** Added a new client-side HUD element that visually tracks active Cosmic Buff durations via a clean, non-intrusive progress bar.
- [Feature] **Cinematic Banners:** The `ShowCinematicBanner` API now supports an optional `theme` argument (e.g. "hazard", "info") that dynamically alters the banner's background tint and styling.
- [Feature] **Sector Load Metrics:** Added a new `sectorLoadMetrics` debug toggle to the Cosmic Config Menu. When enabled, the framework will log exact timestamps and coordinates whenever a sector is generated or entered by a player to help server admins monitor generation performance.

## [v3.2.3]

### 🪲 Bug Fixes
- [Bugfix] **Cosmic Buffs API:** Fixed an issue where dynamically applied jump range buffs (`HyperspaceReach`) from events/weathers were incorrectly scaling as flat numbers (e.g., adding +0.5 sectors) instead of multiplying the ship's base jump range by a percentage.

## [v3.2.2]

### 🐛 Bug Fixes
- [Bugfix] **Config Menu Desync:** Fixed a critical bug in `cosmicconfigmenu.lua` and `ccm.lua` where configuration changes (like hotkeys or toggles) would revert to default values upon reloading a save or logging into a multiplayer server. The API now natively syncs via `Player():getValue(...)`, ensuring all UI elements flawlessly retain their settings across the network without relying on local caching, while restoring proper namespace routing.

## [v3.2.1]
### Fixed
- Fixed an internal multi-script targeting flaw in `cosmicvaultbuffs.lua` that caused `refreshBuff` and `terminateBuff` to only execute on the first loaded `cosmicbuff.lua` instance, instead of properly targeting by buff ID.
- Updated `cosmicbuff.lua` with a new internal `refreshBuffById` hook that safely resets timers without completely recalculating maximum entity shield stats (which interrupts natural out-of-combat regeneration).

## [v3.2.0]

### ✨ New Features & API Expansion
- [API] **Framework Strictness:** Added `CosmicVaultFramework.assertType()` to enforce strict type-checking and prevent silent engine failures across interconnected mods.
- [API] **Mission Automation:** Added `failMission()` and `grantItemReward()` to `cosmicvaultmission.lua` for robust UI handling and physical item reward generation.
- [API] **Fleet Automation:** Expanded `cosmicvaultfleet.lua` with `orderMine()` and `orderSalvage()` to safely push mining/salvaging behaviors to AI ships without rewriting `craftorders.lua`.
- [API] **Physical Upgrades:** Added `SpawnLootUpgrade()` to `cosmicvaultloot.lua`, allowing modders to specifically spawn `SystemUpgradeTemplate` objects physically into space natively.
- [API] **Permanent Buffs:** Added `addPermanentBaseMultiplier()` to `cosmicvaultbuffs.lua` to permanently multiply base stats safely utilizing C++ callbacks without infinitely stacking.
- [API] **Station Distances:** Overhauled `cosmicvaultstation.lua` to support custom `maxDistance` overrides within `isInteractionPossible()` for UI security.

### 🐛 Bug Fixes
- [Bugfix] **Scaling API Crash Fix:** Fixed a severe bug in `cosmicvaultscaling.lua` where calculating defender strength crashed if the native `Galaxy():getControllingFaction()` returned a C++ Faction userdata object instead of an expected numerical index.

## [v3.1.7]

### 🐛 Bug Fixes
- [Bugfix] **API Crash Fixes:** Injected the missing `randomext` engine library into `economyupdater.lua` and `cosmicvaultdialogue.lua`. This prevents a fatal `nil` server crash when a sector experiences a famine and attempts to generate a relief cache, and fixes a silent UI crash in the NPC dialogue generator.

## [v3.1.6]

### ✨ Features & UI
- [Feature] **CCM Permission Tooltips:** Added a dynamic tooltip to all Cosmic Configuration Menu options globally. When hovering over any settings widget (checkboxes, sliders, text boxes), the UI will now explicitly warn players that "Only Server Administrators can change this option". This provides immediate feedback to players on dedicated servers regarding why their changes are being rejected by the server permissions.

### 🐛 Bug Fixes
- [Bugfix] **Rift Escalation Crash & Sync:** Patched `cosmicvaultriftescalation_server.lua`. Added the missing `stringutility` library to prevent fatal text formatting crashes when the server broadcasts escalation warnings. Also removed legacy global wrapper functions that were shadowing the script's namespace and causing native event hook synchronization failures.

## [v3.1.5]

### 🐛 Bug Fixes
- [Bugfix] **Linux Case Sensitivity:** Patched `cosmicvaultterritory.lua` and `cosmicvaultanomalies.lua` to enforce strict casing on `include("SectorGenerator")`. This prevents a fatal `module not found` crash on Linux dedicated servers.

## [v3.1.4]

### 🐛 Bug Fixes

- [Bugfix] **Dynamic Reward Payout Crash:** Proactively fixed a severe bug in the `cosmicvaultmission.lua` backend where the dynamic bounty reward for missions utilized the highly unstable `player:receive()` API overload. The engine would fatally crash upon attempting to award the millions of credits to the victorious player. This has been completely replaced with direct property assignment, permanently securing the reward payout.

## [v3.1.3]

## 🖼️Texture Pack Update

- [Textures] **New Textures:** Added over 16 textures in which the cosmic series utilizes.

## [v3.1.2]

### 🐛 Bug Fixes

- [Bugfix] **API Crash Fix:** Fixed a critical bug in `cosmicvaultfaction.lua` where `cvf.changeRelations` attempted to read the `allianceIndex` property directly from a C++ Faction object instead of casting it to a Player object first. This caused fatal crashes on servers when external mods invoked the relation mirroring function.

## [v3.1.1]

### ⚙️ Changed & Balanced

- [Changed] **Keybind Adjustments:** Unbound the default keys for the Cosmic Vault UI tabs (Cosmic Codex, Config Menu). They now default to unbound to allow players to set their own custom shortcuts without overlapping with other mods.

## [v3.1.0] - Minor Update

### 🛠️ Architecture & Optimization

- [Optimized] **Native UI Integration**: Completely refactored the Weather HUD to utilize Avorion's native `addSectorProblem()` API instead of drawing custom floating text rectangles. Weather warnings now seamlessly hook into your vanilla UI layout with standard icons and hover tooltips.
- [API] **Weather Data Dictionary**: Replaced hardcoded weather logic with a centralized data dictionary (`cosmicvaultweatherdictionary.lua`). Modders can now easily inject custom weather hazards complete with native UI bindings!
- [Balanced] **Dynamic Hazard Protection**: Added a dynamic `isShipPrepared()` callback to the Weather API. Players caught in a Solar Flare who possess a heavily armored ship (Trinium or above) will now natively resist 50% of the physical hull damage.
- [Bugfix] **API Crash Fix**: Fixed a critical server crash in the Weather API's synchronization loop where an invalid engine function (server:getPlayers()) was used instead of server:getOnlinePlayers(). This resolves a severe crash when players log in or weather is created.

## [v3.0.3] - Patch

### 🛠️ API Update & Optimization

- [API] **Precise Siege Timers:** Upgraded `CosmicVaultTerritory.setContestedZone()` to securely store `startTime` inside the serialized sector strings. This guarantees flawless absolute progression tracking and perfectly synchronized visual HUD splitters for joining players, eliminating the visual jump glitch previously seen when joining sieges mid-way. Existing active sieges are backward-compatible.

## [v3.0.2] - Patch

### 🐛 Bug Fixes

- [Bugfixed] **Config Unbind Bug**: Fixed an issue where the Cosmic Config Menu would close itself when players tried to use Escape to unbind a hotkey. Re-mapped the unbind action to the `Delete` or `Backspace` keys, properly displaying this instruction in the capture prompt.
- [Bugfixed] **Chat Hotkey Bleed**: Fixed a highly disruptive bug where CCM hotkeys would randomly fire and open menus while a player was trying to type a sentence in the chat window. The `ccm.lua` API now leverages the `checkInputFocus()` check to block inputs if the player is currently typing in a text field.

## [v3.0.1] - Patch

### 🐛 Bug Fix & 🛠️ Optimization

- [Bugfixed] Fixed a synchronization bug in the Dynamic Weather controller where clients would always default to rendering the "Ion Storm" UI warning regardless of the actual weather type. Weather types are now correctly synchronized and displayed.
- [Optimized] Added high-priority chat warnings for players entering hazard zones (Solar Flares, Dark Matter Fog, etc.).

## [v3.0.0]

### ✨ New Features & 📦 Content Additions

- [Feature] **Custom Faction Traits API**: Added `cosmicvaultfaction.lua` exposing `registerCustomTrait`, `getTrait`, and `setTrait`. This allows modders to easily inject custom faction traits that render beautifully in the native Avorion diplomacy UI!
- [Feature] **Subspace Weather API**: A universal, globally persistent API (`cosmicvaultweather.lua`) allowing any mod to seamlessly generate and clear localized weather hazards.
- [Feature] **Weather UI Integration**: Native HUD indicators (`cv_weather_ui.lua`) that dynamically render active debuff icons and severe weather warnings for players inside hazard zones.
- [Feature] **CosmicVaultEconomy API**: A new API to track faction resource starvation.
- [Feature] **CosmicVaultAnomalies API**: A new API to spawn persistent interactive POIs.
- [Feature] **CCM Keybind API:** Integrated complete hotkey capture suite (`ccm_keycodes.lua`) with modifier (Ctrl/Alt/Shift) support directly into the config framework for robust user-defined keybind injection.
- [Feature] **Config Reset Buttons:** Added dedicated `anticlockwise-rotation` reset buttons with tooltips to immediately revert settings to defaults.
- [Feature] **Global Hotkeys:** Added `hotkeyCodex` (ALT+P) and `hotkeyConfigMenu` (ALT+O) to quickly jump into specific UI panels.
- [Feature] **Custom Economy Engine:** Completely refactored `cosmicvaultgoods.lua` to safely inject custom trade goods into the 5 global vanilla economy arrays dynamically. Added Highlander Shim to `economyupdater.lua` allowing mods to hook dynamic price fluctuations via string callbacks (`CosmicVaultEconomy.registerPriceHook`).
- [Feature] **Dynamic Combat Scaling API:** Added `cosmicvaultscaling.lua` to calculate defensive OM/Volume arrays natively, allowing logic to spawn mathematically balanced or overwhelming invasion fleets.
- [Feature] **Codex 3-Level Hierarchy:** Updated the Cosmic Codex UI to support a dynamic 3-level depth (`Category -> Chapter -> Article`) for superior data organization.
- [Feature] **Territory Expansion API:** Added `cosmicvaultterritory.lua` to allow background mathematical border shifting and station captures without overloading the server.
- [Feature] **Dynamic Faction Generation API:** Added `expandToSector` to `cosmicvaultterritory.lua` allowing mods to natively spawn and instantiate civilized and pirate outposts into uncharted sectors.
- [Feature] **Floating Combat Text & DoTs API:** Added `cosmicvaultcombat.lua` exposing `applyDoT` and native logic to render floating combat text for DOTs dynamically.
- [Feature] **Permanent Buffs API:** Added `applyPermanentFactor` to `cosmicvaultbuffs.lua` to dynamically scale boss shields/damage directly via script natively.
- [Feature] **Global Ascendancy Tier API:** Added `getGlobalTier` and `setGlobalTier` to `cosmicvaultbuffs.lua` to allow cross-sector tracking of global faction buffs (used heavily by Cosmic Ascendancy).
- [Feature] **Salvage Buff Mapping:** Injected native support for `HiddenSectorSalvageYield` into `cosmicbuff.lua`.
- [Feature] **Global Rift Escalation:** The Cosmic Vault now tracks global Rift Guardian kills and Depth 50+ successful extractions.
- [Feature] **Deep Economy Warfare:** `CosmicVaultEconomy` can natively trigger `CosmicWarBridge.forceDeclareWar()` when a faction's famine score exceeds 100, forcing starvation-driven invasions.
- [Feature] **Faction Trait Scaling Integration:** `CosmicVaultScaling` dynamically reads `Cosmic War` diplomatic traits. If an entrenched (Fortified) faction is invaded, their calculated defensive volume and firepower are globally multiplied by `1.3x`.
- [Feature] **Unified News API Framework:** Centralized and fortified `CosmicVaultNews` to securely capture and validate news broadcasts from `Cosmic Chronicles`, `Cosmic War`, and `Cosmic Overhaul`.
- [Feature] **CosmicVaultDialogue API:** Added `maxReputation` and `maxWarHeat` condition parameters to `CosmicVaultDialogue`, properly allowing modders to register dialogue lines strictly for hostile or low-heat contexts.
- [Content] **Famine Relief Anomalies:** Added Famine Relief Anomalies dynamically spawning in starving territories.
- [Content] **Galaxy-wide Threats:** As the global Escalation Level rises, severe vanilla Xsotan attack swarms have an increased chance to converge on all online players simultaneously.

### ⚙️ Changed & ⚖️ Balanced

- [Changed] **Alliance PvP Mirroring**: Upgraded `CosmicVaultFaction.changeRelations` to dynamically mirror reputation shifts to the player's active Alliance, destroying the PvP safe-harbor exploit globally across all Cosmic series mods.
- [Changed] **LDoc Standardization:** Injected comprehensive LDoc style auto-generated docstrings across all exposed library functions (`cosmicvaultarsenal.lua`, `cosmicvaultui.lua`, etc.) to enhance modder readability.
- [Changed] **3-Column HUD Layout:** Revamped Cosmic Config Menu with a cleaner Label | Control | Reset UI ratio.
- [Changed] **UI Polish:** Centered the title in the `Cosmic Codex` UI, and enabled text-wrapping in the `Cosmic Config Menu` labels to prevent overlap.
- [Changed] **UI Notifications:** Upgraded success notifications in Config Menu to use proper `ChatMessageType.Information` overlay.
- [Changed] **Core Dependencies:** Removed `pcall` soft-dependencies. Core 5 mods are now hard requirements for each other.
- [Balanced] **Scaling Sanity Check:** Added a hard cap to `cosmicvaultscaling.lua` to prevent defensive volume scaling from exceeding 500 million (which mathematically crashed Avorion's shipyard generation).
- [Balanced] **Eclipse Immunity:** Adjusted `DarkMatterFog` debuff to ignore Eclipse ships natively.

### 🐛 Bug Fixes & 🛠️ Optimization

- [Optimized] **API Quality Audit:** Conducted a massive static analysis and quality upgrade across all 28 Cosmic Vault core library files.
- [Optimized] **News Broadcaster Interval:** Injected `getUpdateInterval()` into `cosmicvaultnews_server.lua` to ensure the server updates the news queue reliably every second without lagging.
- [Optimized] **Server Thread GC Optimization:** Fixed `cosmicvaultfactionindex.lua` causing massive garbage collection spikes on the Server Thread. Replaced highly inefficient 2,500 consecutive `Faction(i)` C++ boundary creations with native engine property checks, dropping memory footprint to exactly 1 binding per index.
- [Optimized] **Faction Script Casting:** `cosmicvaultmission.lua` `completeMission` had a redundant double-faction cast removed.
- [Bugfixed] **Engine API Bug Fixes:** Fixed multiple Avorion API Indexes across various scripts that could cause C++ attempt to index or attempt to call engine crashes (corrected stat modifier functions, entity bias functions, replaced invalid faction relation setters, and scrubbed `StatsBonuses.ShieldCapacity` from `cosmicbuff.lua` in favor of `ShieldDurability`).
- [Bugfixed] **Engine Crash Prevention:** Injected robust `if not arg then return end` guard clauses and strict validation checks across 13 core Vault APIs, completely eliminating an entire class of Lua crashes when other mods pass uninitialized variables.
- [Bugfixed] **Codex Crash Protection:** Hardened the Codex `[Category]` parsing engine. If a modded article registers to a non-existent category, the Codex will no longer crash to desktop but will instead safely skip rendering the article.
- [Bugfixed] **Cinematic UI Splitters:** Audited all UI components across the Vault and applied proportional `CosmicVaultUI.ShowCinematicBanner` splitters to ensure UI menus scale dynamically on all resolutions without clipping.
- [Bugfixed] **Core Library Hardening:** Performed a massive line-by-line audit of the entire `Cosmic Vault` library. Fixed critical API errors including `Sector():dropUpgrade()` crashes when dropping turrets, `getFactionRelations()` type mismatches, and `invokeFunction` misroutes on the Server object.
- [Bugfixed] **DoT & HoT Persistence:** Completely rewrote `cosmichot.lua` and `cosmicdot.lua` from using volatile `deferredCallback` ghost scripts to persistent `updateServer` loops with `secure()` and `restore()`. This ensures that HoTs and DoTs reliably persist and tick even across sector reloads without vanishing.
- [Bugfixed] **Anomalies Fix:** Resolved a hard crash in `cosmicvaultanomalies.lua` where an empty `Faction()` constructor was being invoked without arguments during entity spawning. It now safely queries the nearest faction.
- [Bugfixed] **Namespace Fixes:** Fixed critical bugs in `cosmicvaultconfig.lua`, `cosmicvaultdebug.lua`, `cosmicvaultframework.lua`, and `cosmicvaultnews.lua` where the script failed to `return` its namespace at the end of the file.
- [Bugfixed] **Codex Dynamic Resizing:** Fixed a UI layout bug where articles missing images caused overlapping text. The UI rect elements now properly scale dynamically to fill empty space.
- [Bugfixed] **Cosmic Config Menu UI Fixes:** Fixed a massive UI bug where clicking a category resulted in a completely blank configuration panel due to Avorion's `Tree:add()` indexing behavior. Fixed an issue where configuration options (checkboxes, sliders) were invisible when selecting a category due to an incorrect Rect initialization.
- [Bugfixed] **Multiplayer Desyncs:** Replaced `math.random` with the deterministic engine `random():getInt()` inside `cosmicvaultencounter.lua` to prevent massive physics and coordinate desyncs when spawning ambushes in multiplayer.
- [Bugfixed] **Rift Mission Vulnerabilities:** Fixed `riftmissionutility.lua` unhandled payload arithmetic crash and table compilation failure. Fixed all vulnerabilities by wrapping the payloads in rigid mathematical type-checks, preventing strings from crashing numerical evaluations.
- [Bugfixed] **Initialization Blockages:** Fixed `init.lua` and `server.lua` fatal initialization blockages. Replaced relative file strings with absolute paths (`"data/scripts/server/..."`) so C++ bindings natively execute them.
- [Bugfixed] **Codex Lua Pattern Injection:** Fixed `cosmiccodex.lua` fatal Lua pattern injection vulnerability. Search bar queries no longer trigger fatal pattern exceptions on special characters.
- [Bugfixed] **Codex Cross-Mod Payloads:** Fixed `cosmiccodex.lua` unhandled cross-mod payload exceptions. Tree builder now mathematically type-enforces all arguments.
- [Bugfixed] **CCM Network Payloads:** Fixed `cosmicconfigmenu.lua` fatal unhandled network payload structural injections. Wrapped all key parsers in rigid mathematical type guards (`type(k) == "string"`).
- [Bugfixed] **Rift Escalation Crash:** Fixed `cv_rift_escalation_tracker.lua` fatal entity death blockage. Wrapped payload extractions in strict mathematical type-checks (`type(count) == "number"`).
- [Bugfixed] **Weather Premature Termination:** Fixed `cv_weather_debuff.lua` catastrophic premature termination bug causing permanent loss of weather penalties on server restarts.
- [Bugfixed] **Weather Immunity Exploit:** Fixed `cv_weather_debuff.lua` player faction immunity bypass where renaming a faction to "The Eclipse" granted fog immunity.
- [Bugfixed] **Weather SQL Vulnerabilities:** Fixed memory corruption vulnerabilities on SQL sector restore inside `cv_weather_debuff.lua` and `cosmicvaultweather_server.lua`.
- [Bugfixed] **Weather Client Sync:** Fixed `cosmicvaultweather_server.lua` fatal client synchronization disconnects caused by relative path mismatch.
- [Bugfixed] **Territory Structural Exceptions:** Fixed `cosmicvaultterritory_server.lua` and `cv_territory_injector_persistent.lua` unhandled structural exceptions and primitive injections in the global territory flipping engine.
- [Bugfixed] **Rift Escalation Loop:** Fixed `cosmicvaultriftescalation_server.lua` math exception thread crash on the background escalator loop.
- [Bugfixed] **Rift Escalation Swarm Trigger:** Fixed `cosmicvaultriftescalation_server.lua` relative path mismatch on the global alien attack trigger.
- [Bugfixed] **News Broadcaster Client Sync:** Fixed `cosmicvaultnews_server.lua` fatal client notification disconnect.
- [Bugfixed] **News SQL Vulnerability:** Fixed `cosmicvaultnews_server.lua` memory corruption vulnerability on server restore and article publication.
- [Bugfixed] **Permanent Storm Debuffs:** Fixed `cv_weather_controller.lua` permanent debuff loop and script path mismatches where cleaning scripts via relative paths permanently broke engine cleanup capability.
- [Bugfixed] **Solar Flare C++ Exception:** Fixed `cv_weather_controller.lua` fatal C++ `inflictDamage` exception caused by an invalid `DamageSource.Collision` enum reference.
- [Bugfixed] **Economy Engine Logic Bugs:** Fixed `economyupdater.lua` multiple fatal string logic vulnerabilities, path mismatches, and incorrect relative script attachment paths.
- [Bugfixed] **Custom Trait Initialization Bomb:** Fixed `diplomacy.lua` silent logic bomb permanently disabling the injection of custom traits due to an uninitialized variable check.
- [Bugfixed] **Custom Trait UI Crashes:** Fixed `diplomacy.lua` fatal UI thread exceptions caused by accessing unvalidated vanilla UI bindings.
- [Bugfixed] **Weather Tracker Paths:** Fixed `cv_player_weather_tracker.lua` fatal script path mismatch and arithmetic exceptions.
- [Bugfixed] **Weather UI Desync:** Fixed `cv_weather_ui.lua` fatal client desynchronization and lack of persistence on server restarts, creating "invisible storms."
- [Bugfixed] **Combat Math Exceptions:** Fixed `cosmicvaultcombat.lua` fatal unhandled parameter types causing Lua arithmetic thread crashes (`entity.durability - amount`).
- [Bugfixed] **Buff Eradication Engine Crash:** Fixed `cosmicvaultbuffs.lua` failure to completely clear overlapping buffs and missing C++ engine type assertions causing server-killing Engine type exceptions.
- [Bugfixed] **Blueprint Type Assertions:** Fixed `cosmicvaultblueprint.lua` missing type assertions for native C++ blueprint loader bindings causing engine halt.
- [Bugfixed] **CCM Keycodes Math Crashing:** Fixed `ccm_keycodes.lua` unhandled type comparison crashes where nil payloads crashed mathematical evaluations.
- [Bugfixed] **CCM Concat Crash:** Fixed `ccm.lua` string concatenation crashes on malformed keys.
- [Bugfixed] **UI Splitter NaN Hazards:** Fixed `cosmicui_proportionalsplitter.lua` missing internal initializers and floating-point logic hazards (divide-by-zero bounds corruption).
- [Bugfixed] **Config API Arguments:** Fixed `cosmicvaultconfig.lua` entirely ignoring the documented `key` and `default` arguments.
- [Bugfixed] **Config API Type Coercion:** Fixed `cosmicvaultconfig.lua` silently discarding configuration integers provided by `ccm` if they were serialized as strings.
- [Bugfixed] **Entity Vararg Crash:** Fixed `cosmicvaultdata.lua` fatal C++ `getEntities()` binding crash natively returning vararg sequences instead of tables.
- [Bugfixed] **Logger Syntax Bug:** Fixed `cosmicvaultdebug.lua` core logging syntax bug where `%s` was literally spammed alongside unformatted strings.
- [Bugfixed] **Weather API Safeties:** Fixed `cosmicvaultweather.lua` missing strict type validations on coordinates and timers.
- [Bugfixed] **Task API Yielding:** Fixed `cosmicvaulttask.lua` missing internal logic for `Yield(duration)` ignoring the requested wait time.
- [Bugfixed] **Station Interaction Crashes:** Fixed `cosmicvaultstation.lua` missing validations in `injectInteraction` and unsafe handling of unowned entities in `isInteractionPossible`.
- [Bugfixed] **Progression API Crashes:** Fixed `cosmicvaultprogression.lua` missing strict validations causing fatal Lua string concatenation crashes.
- [Bugfixed] **Player Settings API Crashes:** Fixed `cosmicvaultplayersettings.lua` failing to validate the `key` argument causing nil concats.
- [Bugfixed] **News Validation Fixes:** Fixed `cosmicvaultnews.lua` missing strict type enforcement on title and content.
- [Bugfixed] **Mission Safeties:** Fixed `cosmicvaultmission.lua` missing validations across Mission APIs.
- [Bugfixed] **Goods Validation:** Fixed `cosmicvaultgoods.lua` failing to parse the `volume` parameter as documented in the Modder Guide (aliases correctly to `size` now).
- [Bugfixed] **Framework API Logic Bugs:** Fixed `cosmicvaultframework.lua` critical error parameter mismatch and `requireCompat` signature missing a required parameter.
- [Bugfixed] **Fleet Order Crashes:** Fixed `cosmicvaultfleet.lua` missing validations on coordinates and entity IDs.
- [Bugfixed] **Faction Relations Hardening:** Fixed `cosmicvaultfaction.lua` missing validations for trait IDs and strictly guarded `changeRelations` against self-relation modification.
- [Bugfixed] **Event UI Crashes:** Fixed `cosmicvaultevents.lua` fatally crashing the client UI and cinematics if evaluated on a client missing the `Server()` object.
- [Bugfixed] **Ambush Logic Crashes:** Fixed `cosmicvaultencounter.lua` violently crashing the server during `spawnAmbush` due to an invalid initialization of `SectorGenerator`, and mutating the cached `spawnMatrix`.
- [Bugfixed] **DoT Damage Signature:** Fixed `cosmicdot.lua` `inflictDamage` signature error passing a float as the damage source enum.
- [Bugfixed] **Famine Engine Crash:** Fixed `cosmicvaulteconomy.lua` invoking a broken `getWealth()` method on Factions instead of their native `.money` property.
- [Bugfixed] **UI Banner Exception:** Fixed `cosmicvaultui.lua` missing validation on `color` arguments causing nil index crashes.
- [Bugfixed] **Cinematic Missing Bridge:** Fixed `cosmicvaultcinematic.lua` `showFloatingText` erroneously aborting when invoked from a Server context due to a missing `invokeClientFunction` forwarder.
- [Bugfixed] **Loot API Types:** Fixed `cosmicvaultloot.lua` passed a raw table instead of a `TradingGood` object to `dropCargo`.
- [Bugfixed] **Codex Missing Info Builder:** Fixed `infoCv.lua` silent injection failure due to relative path hashing on `invokeFunction('ui/cosmiccodex', ...)`.
- [Bugfixed] **UI Translator Comments:** Faction names (like Xsotan) will no longer display raw translator comments (e.g., `/* faction name */`) inside Galactic News articles.
