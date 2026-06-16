# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## v3.0.0 UNRELEASED WORKSHOP VERSION (PROJECT UNDER DEVELOPMENT)

### ✨ Added
- **Custom Faction Traits API**: Added `cosmicvaultfaction.lua` exposing `registerCustomTrait`, `getTrait`, and `setTrait`. This allows modders to easily inject custom faction traits that render beautifully in the native Avorion diplomacy UI!
- **Subspace Weather API**: A universal, globally persistent API (`cosmicvaultweather.lua`) allowing any mod to seamlessly generate and clear localized weather hazards.
- **Weather UI Integration**: Native HUD indicators (`cv_weather_ui.lua`) that dynamically render active debuff icons and severe weather warnings for players inside hazard zones.
- `CosmicVaultEconomy` API to track faction resource starvation.
- `CosmicVaultAnomalies` API to spawn persistent interactive POIs.
- **News Broadcaster Interval**: Injected `getUpdateInterval()` into `cosmicvaultnews_server.lua` to ensure the server updates the news queue reliably every second without lagging.
- **CCM Keybind API:** Integrated complete hotkey capture suite (`ccm_keycodes.lua`) with modifier (Ctrl/Alt/Shift) support directly into the config framework.
- **3-Column HUD Layout:** Revamped Cosmic Config Menu with a cleaner Label | Control | Reset UI ratio.
- **Config Reset Buttons:** Added dedicated `anticlockwise-rotation` reset buttons with tooltips to immediately revert settings to defaults.
- **Global Hotkeys:** Added `hotkeyCodex` (ALT+P) and `hotkeyConfigMenu` (ALT+O) to quickly jump into specific UI panels.
- **Custom Economy Engine:** Completely refactored `cosmicvaultgoods.lua` to safely inject custom trade goods into the 5 global vanilla economy arrays dynamically. Added Highlander Shim to `economyupdater.lua` allowing mods to hook dynamic price fluctuations via string callbacks (`CosmicVaultEconomy.registerPriceHook`).
- **Dynamic Combat Scaling API:** Added `cosmicvaultscaling.lua` to calculate defensive OM/Volume arrays natively, allowing logic to spawn mathematically balanced or overwhelming invasion fleets.
- **Codex 3-Level Hierarchy:** Updated the Cosmic Codex UI to support a dynamic 3-level depth (`Category -> Chapter -> Article`) for superior data organization.
- **Territory Expansion API:** Added `cosmicvaultterritory.lua` to allow background mathematical border shifting and station captures without overloading the server.
- **Dynamic Faction Generation API:** Added `expandToSector` to `cosmicvaultterritory.lua` allowing mods to natively spawn and instantiate civilized and pirate outposts into uncharted sectors.
- **Floating Combat Text & DoTs API:** Added `cosmicvaultcombat.lua` exposing `applyDoT` and native logic to render floating combat text for DOTs dynamically.
- **Permanent Buffs API:** Added `applyPermanentFactor` to `cosmicvaultbuffs.lua` to dynamically scale boss shields/damage directly via script natively.
- **Global Ascendancy Tier API:** Added `getGlobalTier` and `setGlobalTier` to `cosmicvaultbuffs.lua` to allow cross-sector tracking of global faction buffs (used heavily by Cosmic Ascendancy).

### 🛠️ Improved & Upgraded
- **Codex UI:** Resizing logic gracefully handles missing images without text overlapping.
- **API Quality Audit:** Conducted a massive static analysis and quality upgrade across all 28 Cosmic Vault core library files.
- **LDoc Standardization:** Injected comprehensive LDoc style docstrings across all exposed library functions (`cosmicvaultarsenal.lua`, `cosmicvaultui.lua`, etc.) to enhance modder readability.
- **Engine Crash Prevention:** Injected robust `if not arg then return end` guard clauses into all API endpoints, completely eliminating an entire class of Lua crashes when other mods pass uninitialized variables to the Vault.
- **Namespace Fixes:** Fixed critical bugs in `cosmicvaultconfig.lua`, `cosmicvaultdebug.lua`, `cosmicvaultframework.lua`, and `cosmicvaultnews.lua` where the script failed to `return` its namespace at the end of the file.

### 🐛 Bug Fixes & Optimization
- **Keybind Reliability:** Fully integrated robust user-defined keybind injection.
- **Codex Dynamic Resizing:** Fixed a UI layout bug where articles missing images caused overlapping text. The UI rect elements now properly scale dynamically to fill empty space.
- **Cosmic Config Menu Fix:** Fixed a massive UI bug where clicking a category resulted in a completely blank configuration panel due to Avorion's `Tree:add()` indexing behavior. A custom `treeValues` mapping correctly fetches namespaces.
- **Cosmic Config Menu:** Fixed an issue where configuration options (checkboxes, sliders) were invisible when selecting a category due to an incorrect `Rect` initialization.
- **UI Polish:** Faction names (like Xsotan) will no longer display raw translator comments (e.g., `/* faction name */`) inside Galactic News articles.
- **Multiplayer Desyncs:** Replaced `math.random` with the deterministic engine `random():getInt()` inside `cosmicvaultencounter.lua` to prevent massive physics and coordinate desyncs when spawning ambushes in multiplayer.
- Removed `pcall` soft-dependencies. Core 5 mods are now hard requirements for each other.
- Adjusted `DarkMatterFog` debuff to ignore Eclipse ships.
- **Invalid API Sweeps**: Scrubbed `StatsBonuses.ShieldCapacity` from `cosmicbuff.lua` and replaced it with the native engine `StatsBonuses.ShieldDurability`.
