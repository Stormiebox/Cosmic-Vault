# Cosmic Vault - Detailed Features

This page contains the full, detailed documentation for **Cosmic Vault**, the shared foundation layer for the Cosmic mod series.

Cosmic Vault is intended to centralize reusable code, configuration patterns, and shared assets so other Cosmic mods can:
- avoid duplicate implementations,
- stay behavior-consistent,
- and integrate faster with lower maintenance cost.

---

## Mod Identity & Purpose

**Cosmic Vault** is infrastructure-first.

Unlike feature-heavy gameplay mods, Cosmic Vault focuses on:
- shared utilities,
- common debug/diagnostics standards,
- modular helper libraries,
- and reusable series-wide patterns.

### Primary dependents (current direction)
- Cosmic Overhaul
- Cosmic War
- Cosmic Starfall

---

## Core Design Principles

1. **Single source of truth for shared helpers**
2. **Optional, safe include patterns where possible**
3. **Consistent logging and diagnostics conventions**
4. **Minimal duplication across Cosmic mods**
5. **Backward-compatible, extensible utility APIs**

---

## Current Foundation Scope

## 1) Shared Configuration Baseline (MCM)
**Primary files:**
- `modconfig.lua`
- `modinfo.lua`

### What it does
Provides base configuration schema for shared Cosmic-level utility controls.

### Current baseline controls (planned/active pattern)
- `debugEnabled`
- `debugPrefix`
- `diagnosticsEnabled`
- `diagnosticsInterval`

### Why it matters
A centralized config baseline helps dependent mods align behavior without duplicating per-mod boilerplate.

---

## 2) Shared Utility / Library Hub (Series Foundation)
**Primary path target:**
- `data/scripts/lib/`

### Intended content
- shared config adapters
- shared debug/log wrappers
- shared utility helpers
- common data normalization helpers
- compatibility helpers used by multiple Cosmic mods

### Why it matters
Prevents repeated reimplementation of near-identical helper code in each mod.

---

## 3) Shared Diagnostics Pattern
**Primary path target:**
- `data/scripts/lib/` and optional server helpers

### What it does
Defines a common diagnostics convention for:
- periodic snapshots,
- standardized debug prefixes,
- consistent opt-in verbosity.

### Why it matters
Makes troubleshooting across mixed Cosmic stacks easier and more uniform.

---

## 4) Shared Visual/Asset Layer
**Primary path target:**
- `data/textures/`

### What it does
Hosts reusable visual resources (icons/textures) used by multiple Cosmic mods.

### Why it matters
- consistent visual identity,
- no repeated asset copies,
- easier coordinated updates.

---

## 5) Dependency Contract for Cosmic Series
### What it does
Acts as a formal dependency target that future Cosmic modules can reference in `modinfo.lua`.

### Typical dependent behavior
- Declare Cosmic Vault as dependency.
- Include shared config/debug libraries from Vault.
- Route diagnostics through Vault conventions.

### Why it matters
Stabilizes cross-mod expectations and reduces maintenance fragmentation over time.

---

## Integration Contract (For Dependent Mods)

When integrating with Cosmic Vault, dependent mods should generally:

1. Declare dependency in `modinfo.lua`.
2. Use shared includes (where available), e.g.:
   - `include("cosmicvaultconfig")`
   - `include("cosmicvaultdebug")`
3. Follow Vault debug prefix + diagnostics conventions.
4. Keep fallback behavior safe if optional helpers are absent during transitional phases.

---

## Example Integration Pattern (High-Level)

A dependent mod can follow this approach:

1. Load Vault helper with guarded include (during migration windows if needed).
2. Read shared config keys for debug/diagnostics behavior.
3. Route log output through shared formatter/prefix.
4. Keep mod-specific logic separate from shared helper internals.

This ensures series-wide consistency while preserving per-mod gameplay identity.

---

## Architecture Position in Cosmic Series

Think of Cosmic Vault as:

- **Foundation layer** → provides common building blocks.
- **Gameplay mods** (Overhaul/War/Starfall/etc.) → consume those blocks for their own domain-specific logic.

This separation improves:
- maintainability,
- onboarding speed,
- and cross-mod compatibility reliability.

---

## Current Status

**Lifecycle status:** Foundational bootstrap + expansion phase.

### Already established
- base metadata and config structure
- project scaffold
- initial documentation baseline

### Ongoing / next growth targets
- expand `data/scripts/lib/` shared helper catalog
- standardize diagnostics helper interfaces
- provide stable helper APIs for dependent mods
- migrate duplicate utility patterns out of dependent mods into Vault

---

## Compatibility & Safety Notes

- Vault is intended as an additive foundation, not a hard gameplay override system.
- Shared helper interfaces should remain conservative and backward-aware.
- Avoid tight coupling that would force runtime failure in mixed mod stacks during transition phases.

---

## Installation

1. Place folder in:
   - Windows: `%AppData%\Avorion\mods\`
   - Linux: `~/.avorion/mods/`
2. Enable Cosmic Vault in **Settings -> Mods**.
3. Restart Avorion when prompted.

---

## Troubleshooting Checklist

1. Confirm Cosmic Vault is enabled.
2. Confirm dependent mod dependency declarations are correct.
3. Verify include paths for shared libs under `data/scripts/lib/`.
4. Check logs for missing helper modules during migration windows.
5. Keep mod load order consistent in larger stacks.

---

## Development Direction

Cosmic Vault is designed to become the stable utility backbone for the entire Cosmic series.

Future progress emphasizes:
- robust shared libraries,
- cleaner cross-mod contracts,
- and reduced duplication across all Cosmic gameplay modules.
