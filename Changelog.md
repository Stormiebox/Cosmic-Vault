# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

--

## v2.1.0 (CURRENT PROJECT VERSION - NO RELEASE DATE YET!)

### Added
- **Floating Combat Text & DoTs API**: Added `cosmicvaultcombat.lua` exposing `applyDoT` and native logic to render floating combat text for DOTs dynamically.
- **Permanent Buffs API**: Added `applyPermanentFactor` to `cosmicvaultbuffs.lua` to dynamically scale boss shields/damage directly via script natively.

### Added
- **Global Ascendancy Tier API**: Added `getGlobalTier` and `setGlobalTier` to `cosmicvaultbuffs.lua` to allow cross-sector tracking of global faction buffs (used heavily by Cosmic Ascendancy).

### Changed
- Fully integrated with the Cosmic Vault API framework.
- Swept codebase for legacy callbacks and implemented safe pcall fallbacks.

### LEGACY LOGS BELOW - KEPT FOR HISTORICAL PURPOSES

## [2.0.1] Missing Galaxy Map QoL

### Added

- **Missing Texture:** Added missing texture for Galaxy Map QoL

## [2.0.0]

### Added

- **Major Modding APIs Expansion:** Introduced a suite of 5 new unified APIs to assist modders in creating powerful Vanilla+ experiences without needing to execute dangerous 'hard overrides' of core vanilla game files.
- **Cosmic Vault Task API:** Added cosmicvaulttask.lua. Allows modders to run intensive operations (like scanning the galaxy) across multiple server ticks using Lua Coroutines, completely preventing massive TPS drops or server hangs.
- **Cosmic Vault Data API:** Added cosmicvaultdata.lua. Provides universal Entity Tagging and JSON serialization, allowing complex nested tables to be easily stored and fetched directly on/from Avorion entities.
- **Cosmic Vault Arsenal API:** Added cosmicvaultarsenal.lua. Provides a template-driven math generator that dynamically creates perfectly balanced InventoryTurret and Weapon objects for custom loot tables and enemy designs.
- **Cosmic Vault Cinematic UI API:** Added cosmicvaultui.lua and cosmicvaultcinematic.lua. Provides native support for triggering immersive, stylized on-screen notification banners and popups with sound effects.
- **Cosmic Vault Economy API:** Added cosmicvaulteconomy.lua. Provides native simulation hooks for injecting custom dynamic trade goods, and triggering market Booms or Crashes which automatically interface with the Galactic News Network.
- **Cosmic Vault Dynamic Encounters API:** Added cosmicvaultencounter.lua. Safely uses `onPlayerEntered` callbacks to inject custom ambushes, anomalies, or bosses dynamically, perfectly preserving vanilla sector generation.
- **Cosmic Vault Mission Injector API:** Added cosmicvaultmission.lua. Streamlines the creation of custom missions and natively injects them into Bulletin Boards without overriding station scripts.
- **Cosmic Vault Progression API:** Added cosmicvaultprogression.lua. A unified framework for granting custom XP, skill trees, and perks, automatically syncing them natively between client and server.
- **Cosmic Vault Fleet Command API:** Added cosmicvaultfleet.lua. A clean interface to safely push AI orders (patrol, escort, mine) without needing to rewrite `craftorders.lua`.
- **Cosmic Vault Faction Traits API:** Added cosmicvaultfaction.lua. Natively applies temporary reputation traits (e.g. Aggressive, Isolationist) to AI factions to dynamically alter how they behave toward players.
- **Cosmic Vault Custom Goods API:** Added cosmicvaultgoods.lua. Safely appends custom trade goods to the global economy without overriding `goods.lua`.
- **Cosmic Vault Custom Loot API:** Added cosmicvaultloot.lua. Hooks into native destruction events to drop custom weapons, upgrades, and goods from enemies dynamically.
- **Cosmic Vault Blueprint Spawner API:** Added cosmicvaultblueprint.lua. Allows modders to spawn custom XML ships, stations, and turrets dynamically with proper scaling and crew.
- **Cosmic Vault Station Interaction API:** Added cosmicvaultstation.lua. Simplifies injecting custom UI tabs and interactions into vanilla stations safely.
- **Cosmic Vault Global Events API:** Added cosmicvaultevents.lua. Wraps `Server():setValue()` to manage and sync galaxy-wide timed events natively across reboots.
- **Cosmic Vault Buff & Debuff API:** Added cosmicvaultbuffs.lua & cosmicbuff.lua. Dynamically attaches self-terminating scripts to ships to securely alter their stats temporarily (e.g. Speed, Damage).

## [1.5.0] - 2026-06-07

### Fixed

- **Architecture Validation:** Validated `server/server.lua` architecture. Unlike `init.lua` bootstrappers, the Avorion engine treats `server.lua` as an implicitly attached entity script on the Server object, meaning the `initialize()` wrapper correctly and safely functions as intended to inject the global Vault News server.
- **Global Event Bus:** Refactored `cosmicvaultnews_server.lua` to properly accept sync requests from player UI scripts across the server via Avorion's asynchronous `Server():registerCallback` and `Server():sendCallback` system, bypassing strict VM sandboxing limits.
- **Compliance Fix:** Wrapped core injection files (init.lua) safely to prevent them from wiping out vanilla initialization scripts.
- **Re-entrant VM Deadlock:** Fixed a critical server crash (`EXCEPTION_ACCESS_VIOLATION`) that occurred when a player loaded into the galaxy. The `cosmicvaultnews_server.lua` broadcasting mechanism was decoupled from the synchronous callback chain using an `updateServer()` state flag (`needsPlayerNotification`), safely allowing the engine to broadcast news outside of locked Lua VMs.
- **News Publishing API Crash Fix:** Fixed a silent API crash in the Cosmic Vault News library. Replaced an invalid `Server.invokeFunction` call with Avorion's native `Server():sendCallback()` event bus, ensuring external mod events (and Vanilla events) can successfully publish articles without silently terminating execution.

### Added

- **Galactic News API:** Introduced the `cosmicvaultnews.lua` library and its companion server hub `cosmicvaultnews_server.lua`.
  - Exposes `CosmicVaultNews.publishArticle(article)` which allows any mod in the ecosystem to globally broadcast dynamic news events to all players.
  - Features a built-in server buffer that automatically manages the latest 30 articles and handles client synchronization to support custom news UI tabs (like the one implemented in *Cosmic Chronicles*).
  - Includes a pool of 35 randomized reporter names (e.g. Jade, Vance, Nyx, Orion) to automatically author breaking news articles and enhance immersion.

- **Cosmic UI Proportional Splitters:** Ported the core UI proportional splitter classes natively into the Vault (cosmicui_proportionalsplitter.lua), completely decoupling the Cosmic series from relying on external, unmaintained legacy UI libraries.

  - Broadcasts the global client-side callback `onCosmicVaultNewsUpdated` whenever a new article drops, allowing any listening UI scripts to instantly synchronize and update their displays in real-time.

- **Texture Folder Migration:** Added textures from `Cosmic War`, `Cosmic Overhaul` and `Cosmic Chronicles`. Cosmic Vault will now be the shared library for textures moving forward.

## [1.4.0] - 2026-05-31 - Synced with Cosmic Overhaul v4.0.0, Cosmic War v1.6.0 and Cosmic Chronicles v1.1.0 updates

### Added

- **Player Settings API**: Introduced `data/scripts/lib/cosmicvaultplayersettings.lua`, a new centralized API for storing and retrieving player-specific settings. This system uses the performant and persistent `Player():getValue()` and `setValue()` system, completely replacing the need for direct file I/O via `moddata.lua` and eliminating a major source of crashes on fresh servers.

### Changed

- **Faction Indexer Warm-up:** Tweaked `cosmicvaultfactionindex.lua` to include a short 15-second warm-up delay on the first server boot before switching to the standard 5-minute refresh cycle. This ensures the registry rapidly catches initial faction generations when a new galaxy is loaded.
- **Cosmic Series Debug:** Changed the default value from false to true so `[Cosmic]` debug logs is always on unless disabled by an admin. This will help logging all actions done by the Cosmic Series (where appliclable) done from the get-go.

### Removed

- **AzimuthLib - Library for modders (Mod Dependency):** Due to the recent changes done to Cosmic Overhaul v4.0.0 and the additions of new API's onto Cosmic Vault. AzimuthLib - Library for modders is no longer needed as a dependency mod for the Cosmic Series.

## [1.3.0] - 2026-05-24

### Fixed

- **Faction Indexer (High-ID Preservation):** Fixed a critical blind spot in `cosmicvaultfactionindex.lua` where the registry would only scan standard AI faction IDs (1 to 2500). It now properly parses its own cache to preserve discovered dynamically generated factions (Pirates, Xsotan, DLC factions) that have IDs far beyond the 2500 threshold, preventing them from being wiped out during background refresh cycles.

## [1.2.0] - 2026-05-22

### Added

- **Cosmic Dialogue Index API**: Introduced `data/scripts/lib/cosmicvaultdialogue.lua`, a centralized registry and retrieval system for lore and dialogue.
- Provided a shared contract for narrative mods (specifically **Cosmic Chronicles**) to safely register and pull context-aware strings.
- Added dynamic context filtering support for: `minWarHeat`, `factionTrait`, `factionWealth`, `stationType`, `minDistanceToCenter`, `maxDistanceToCenter`, and `minReputation`.
- Integrated error handling and debug logging via `CosmicVaultDebug` for safe dialogue registration.

### Optimized

- **Dialogue Validation:** Fast-failed the sequential condition checks in `cosmicvaultdialogue.lua` using short-circuit evaluation (`isValid and ...`) to save server CPU cycles during heavy chatter.

## [1.1.0] - 2026-05-18

### Added

- **Cosmic Faction Index API**: Introduced a centralized, highly performant background script (`cosmicvaultfactionindex.lua`) that safely scans, deduplicates, and caches a list of all active faction indices.
- Added `data/scripts/galaxy/init.lua` to automatically bootstrap the Faction Indexer into the Avorion `Galaxy` loop on server startup.
- Established a shared Server Data Contract for dependent Cosmic mods to safely consume faction data without expensive or invalid API calls:
  - `factions` (table): The canonical list of active faction indices.
  - `factions_ready` (boolean): Safety flag indicating the indexer has completed its first warm-up cycle.
  - `factions_count` (number): The total number of indexed factions.
  - `factions_last_refresh` (number): The unpaused server runtime when the cache was last rebuilt.
- Created/expanded foundational documentation for Cosmic Vault as a shared Cosmic-series base module.
- Added comprehensive wiki documentation:
  - `Cosmic_Vault_Wiki.md` (full architecture goals, integration contract, and module direction).

### Changed

- Simplified `README.md` to a concise high-level overview with clear direction to wiki for full details.

### Notes

- Cosmic Vault is currently in foundation-expansion phase.
- Future entries should document concrete shared library additions under `data/scripts/lib/` and any dependency contract changes used by dependent Cosmic mods.
