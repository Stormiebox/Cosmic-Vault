# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-06-06
### Fixed
- **Architecture Validation:** Validated `server/server.lua` architecture. Unlike `init.lua` bootstrappers, the Avorion engine treats `server.lua` as an implicitly attached entity script on the Server object, meaning the `initialize()` wrapper correctly and safely functions as intended to inject the global Vault News server.
- **Global Event Bus:** Refactored `cosmicvaultnews_server.lua` to properly accept sync requests from player UI scripts across the server via Avorion's asynchronous `Server():registerCallback` and `Server():sendCallback` system, bypassing strict VM sandboxing limits.
- **Compliance Fix:** Wrapped core injection files (init.lua) safely to prevent them from wiping out vanilla initialization scripts.

### Added
- **Galactic News API:** Introduced the `cosmicvaultnews.lua` library and its companion server hub `cosmicvaultnews_server.lua`.
  - Exposes `CosmicVaultNews.publishArticle(article)` which allows any mod in the ecosystem to globally broadcast dynamic news events to all players.
  - Features a built-in server buffer that automatically manages the latest 30 articles and handles client synchronization to support custom news UI tabs (like the one implemented in *Cosmic Chronicles*).

- **Cosmic UI Proportional Splitters:** Ported the core UI proportional splitter classes natively into the Vault (cosmicui_proportionalsplitter.lua), completely decoupling the Cosmic series from relying on external, unmaintained legacy UI libraries.

  - Broadcasts the global client-side callback `onCosmicVaultNewsUpdated` whenever a new article drops, allowing any listening UI scripts to instantly synchronize and update their displays in real-time.

- **Texture Folder Migration:** Added textures from `Cosmic War`, `Cosmic Overhaul` and `Cosmic Chronicles`. Cosmic Vault will now be the shared library for textures moving forward.

## [1.4.0] - 2026-05-31 - Synced with Cosmic Overhaul v4.0.0, Cosmic War v1.6.0 and Cosmic Chronicles v1.1.0 updates.

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


