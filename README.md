# Cosmic Vault

Cosmic Vault is the shared foundation mod for the Cosmic series.

## Purpose

Cosmic Vault centralizes shared code, tools, and assets used across Cosmic mods, including:

- Common debug/logging utilities
- Shared diagnostics helpers
- Reusable utility modules
- Shared visual assets and icons

Initial required dependents:

- Cosmic Overhaul
- Cosmic War

Future Cosmic series mods should depend on Cosmic Vault to avoid duplicated code and to keep behavior consistent.

## Folder Structure

Planned structure:

- `data/scripts/lib/`
  - shared config and debug utilities
  - shared utility/helper modules
- `data/scripts/server/`
  - optional server helpers used by multiple Cosmic mods
- `data/scripts/client/`
  - optional client/UI helpers
- `data/textures/`
  - shared icons and texture assets

## Configuration (MCM)

Cosmic Vault includes a base Mod Configuration Menu with:

- `debugEnabled`: Master toggle for Cosmic debug logs
- `debugPrefix`: Prefix for Cosmic log entries
- `diagnosticsEnabled`: Enables diagnostics helpers
- `diagnosticsInterval`: Update interval for diagnostics snapshots

## Integration Notes

Dependent Cosmic mods should:

1. Add `CosmicVault` as a dependency in `modinfo.lua`
2. Use `include("cosmicvaultconfig")` and `include("cosmicvaultdebug")` once those shared libs are added
3. Route mod-specific debug output through Cosmic Vault shared logging helpers

## Status

Bootstrap phase complete:
- Base metadata exists
- Base MCM config exists
- README baseline created

Next step is adding first shared library modules in `data/scripts/lib/`.
