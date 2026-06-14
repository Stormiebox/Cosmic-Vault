# Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## v2.1.0 (CURRENT PROJECT VERSION - NO RELEASE DATE YET!)

### ✨ Added
- **Codex 3-Level Hierarchy:** Updated the Cosmic Codex UI to support a dynamic 3-level depth (`Category -> Chapter -> Article`) for superior data organization.
- **Territory Expansion API:** Added `cosmicvaultterritory.lua` to allow background mathematical border shifting and station captures without overloading the server.
- **Floating Combat Text & DoTs API:** Added `cosmicvaultcombat.lua` exposing `applyDoT` and native logic to render floating combat text for DOTs dynamically.
- **Permanent Buffs API:** Added `applyPermanentFactor` to `cosmicvaultbuffs.lua` to dynamically scale boss shields/damage directly via script natively.
- **Global Ascendancy Tier API:** Added `getGlobalTier` and `setGlobalTier` to `cosmicvaultbuffs.lua` to allow cross-sector tracking of global faction buffs (used heavily by Cosmic Ascendancy).

### 🐛 Bug Fixes & Optimization
- **Codex Dynamic Resizing:** Fixed a UI layout bug where articles missing images caused overlapping text. The UI rect elements now properly scale dynamically to fill empty space.
- **Cosmic Config Menu Fix:** Fixed a massive UI bug where clicking a category resulted in a completely blank configuration panel due to Avorion's `Tree:add()` indexing behavior. A custom `treeValues` mapping correctly fetches namespaces.
- **Cosmic Config Menu:** Fixed an issue where configuration options (checkboxes, sliders) were invisible when selecting a category due to an incorrect `Rect` initialization.
- **UI Polish:** Faction names (like Xsotan) will no longer display raw translator comments (e.g., `/* faction name */`) inside Galactic News articles.
- **Multiplayer Desyncs:** Replaced `math.random` with the deterministic engine `random():getInt()` inside `cosmicvaultencounter.lua` to prevent massive physics and coordinate desyncs when spawning ambushes in multiplayer.
