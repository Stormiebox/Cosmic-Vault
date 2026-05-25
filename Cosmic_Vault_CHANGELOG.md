# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
