# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

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
