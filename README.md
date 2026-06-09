# Cosmic Vault

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Cosmic Vault** is the shared foundation module for the Cosmic mod series.

It centralizes reusable infrastructure so Cosmic mods can share:

- utility code,
- diagnostics/logging patterns,
- common configuration behavior,
- dynamic dialogue & lore registries,
- and shared assets.

---

## Full Documentation

For complete architecture and integration details, see:

- **`Cosmic_Vault_Wiki.md`**

---

## Quick Highlights

- Establishes common baseline patterns for cross-mod consistency.
- Centralizes shared UI layout APIs (e.g., Cosmic UI Proportional Splitters) to completely decouple mods from legacy external libraries.
- Includes the **Galactic News API** for broadcasting rich, real-time ecosystem updates to players.
- Features highly performant Server Data Contracts (like Faction Indexing and Contextual Dialogue).
- **Extensive Modding APIs**: Includes a powerful suite of 16 custom APIs (Task Scheduler, Arsenal Generator, Entity Data, Economy, Cinematic UI, Dynamic Encounters, Mission Injector, Progression, Fleet Command, Faction Traits, Custom Goods, Custom Loot, Blueprint Spawner, Station Interaction, Global Events, and Buffs/Debuffs) to help modders create Vanilla+ experiences without hard overrides!
- Reduces duplicate helper code across Cosmic projects.
- Intended dependency target for current and future Cosmic modules (Overhaul, War, Starfall, Chronicles).

---

## Installation

1. Place folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Enable **Cosmic Vault** in **Settings -> Mods**.
3. Restart Avorion when prompted.

---

## Integration Snapshot (For Dependent Mods)

Dependent mods should:

1. Declare Cosmic Vault in `modinfo.lua` dependencies.
2. Use shared Vault helpers (where available) from `data/scripts/lib/`.
3. Align debug/diagnostics behavior with Vault conventions.

---

## Project Notes

- Cosmic Vault is infrastructure-first, not a direct gameplay overhaul.
- See `CHANGELOG.md` for ongoing foundation expansion and shared-lib additions.

