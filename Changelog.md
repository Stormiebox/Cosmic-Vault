# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## v2.1.0 (CURRENT PROJECT VERSION - NO RELEASE DATE YET!)

### Bug Fixes
- **UI Polish:** Faction names (like Xsotan) will no longer display raw translator comments (e.g., `/* faction name */`) inside Galactic News articles.

### Added
- **Territory Expansion API**: Added `cosmicvaultterritory.lua` to allow background mathematical border shifting and station captures without overloading the server.
- **Floating Combat Text & DoTs API**: Added `cosmicvaultcombat.lua` exposing `applyDoT` and native logic to render floating combat text for DOTs dynamically.
- **Permanent Buffs API**: Added `applyPermanentFactor` to `cosmicvaultbuffs.lua` to dynamically scale boss shields/damage directly via script natively.

### Added
- **Global Ascendancy Tier API**: Added `getGlobalTier` and `setGlobalTier` to `cosmicvaultbuffs.lua` to allow cross-sector tracking of global faction buffs (used heavily by Cosmic Ascendancy).

### Changed
- Fully integrated with the Cosmic Vault API framework.
- Swept codebase for legacy callbacks and implemented safe pcall fallbacks.