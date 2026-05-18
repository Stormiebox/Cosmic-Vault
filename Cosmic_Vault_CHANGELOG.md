# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
