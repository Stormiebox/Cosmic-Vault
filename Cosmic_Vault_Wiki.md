# Cosmic Vault - Detailed Features

Welcome to the **Cosmic Vault** official wiki! This page contains the full, detailed documentation for the shared foundation layer of the **Cosmic** mod series.

**Cosmic Vault** is intended to centralize reusable code, configuration patterns, and shared assets so other mods in the series can:

- Avoid duplicate implementations.
- Stay behavior-consistent.
- Integrate faster with lower maintenance costs.

---

## Table of Contents

- [Mod Identity & Purpose](#mod-identity--purpose)
- [Core Design Principles](#core-design-principles)
- [Foundation Scope & Features](#foundation-scope--features)
- [Integration Guidelines](#integration-guidelines)
- [Ecosystem & Architecture](#ecosystem--architecture)
- [Installation & Troubleshooting](#installation--troubleshooting)
- [Development Status](#development-status)

---

## Mod Identity & Purpose

**Cosmic Vault** is an infrastructure-first module.

Unlike feature-heavy gameplay mods, **Cosmic Vault** focuses exclusively on:

- Shared utilities.
- Common debug and diagnostics standards.
- Modular helper libraries.
- Reusable, series-wide architectural patterns.

### Primary Dependents (Current Direction)

- **Cosmic Overhaul**
- **Cosmic War**
- **Cosmic Starfall**
- **Cosmic Chronicles**

---

## Core Design Principles

1. **Single Source of Truth:** Centralize shared helpers.
2. **Safe Inclusions:** Utilize optional, safe include patterns wherever possible.
3. **Consistent Diagnostics:** Establish uniform logging and diagnostics conventions.
4. **Minimal Duplication:** Reduce code duplication across all **Cosmic** mods.
5. **Backward Compatibility:** Provide extensible, backward-compatible utility APIs.

---

## Foundation Scope & Features

### 1) Galactic News API (Broadcasting Hub)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**
- `data/scripts/lib/cosmicvaultnews.lua`
- `data/scripts/server/cosmicvaultnews_server.lua`

**What it does:**
Acts as the central nervous system for galactic broadcasting. Any mod in the Cosmic series can use this API to instantly publish dynamic news articles to the global server buffer. 

**Key Methods:**
- `CosmicVaultNews.publishArticle(article)`: Safely pipes a formatted article (title, category, content) into the server.
- **Server Sync:** Automatically manages memory by holding the latest 30 articles and seamlessly broadcasting updates to all connected players for custom UI rendering (e.g., *Cosmic Chronicles'* Galactic News Board).
- **Client Callbacks:** Broadcasts `onCosmicVaultNewsUpdated` directly to clients so custom UI boards can refresh in real-time.

</details>


### 2) Cosmic UI Proportional Splitters

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**
- data/scripts/lib/cosmicui_proportionalsplitter.lua

**What it does:**
Provides native UI layout tools that allow developers to design complex interfaces by mixing absolute pixel measurements with fluid percentage-based proportions. Completely removes the need for external legacy UI dependencies like AzimuthLib.

**Key Methods:**
- CosmicUIVerticalProportionalSplitter()
- CosmicUIHorizontalProportionalSplitter()

</details>

### 3) Shared Configuration Baseline (MCM)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `modconfig.lua`
- `modinfo.lua`

**What it does:**
Provides a base configuration schema for shared Cosmic-level utility controls.

**Current Baseline Controls (Planned/Active Pattern):**

- `debugEnabled` (Defaults to `true` to ensure comprehensive logging from the get-go unless disabled by an admin)
- `debugPrefix`
- `diagnosticsEnabled`
- `diagnosticsInterval`

**Why it matters:**
A centralized configuration baseline helps dependent mods align behavior without duplicating per-mod boilerplate.
</details>

### 4) Shared Utility / Library Hub (Series Foundation)

<details>
<summary><b>Click to expand details</b></summary>

**Primary path target:**

- `data/scripts/lib/`

**Intended Content:**

- Shared config adapters.
- Shared debug and log wrappers.
- Shared utility helpers.
- Common data normalization helpers.
- Compatibility helpers utilized by multiple Cosmic mods.

**Why it matters:**
Prevents the repeated reimplementation of near-identical helper code in each individual mod.
</details>

### 5) Shared Diagnostics Pattern

<details>
<summary><b>Click to expand details</b></summary>

**Primary path targets:**

- `data/scripts/lib/` and optional server helpers

**What it does:**
Defines a common diagnostics convention for:

- Periodic snapshots.
- Standardized debug prefixes.
- Consistent opt-in verbosity.

**Why it matters:**
Makes troubleshooting across mixed Cosmic mod stacks significantly easier and more uniform.
</details>

### 6) Shared Visual/Asset Layer

<details>
<summary><b>Click to expand details</b></summary>

**Primary path target:**

- `data/textures/`

**What it does:**
Hosts reusable visual resources (such as icons and textures) used by multiple Cosmic mods.

**Why it matters:**

- Ensures a consistent visual identity.
- Eliminates repeated asset copies to save memory and disk space.
- Enables easier, coordinated graphical updates.

</details>

### 7) Dependency Contract for Cosmic Series

<details>
<summary><b>Click to expand details</b></summary>

**What it does:**
Acts as a formal dependency target that future Cosmic modules can safely reference in their `modinfo.lua`.

*(Note: As of v1.4.0, Cosmic Vault's robust APIs have completely replaced the need for legacy third-party library dependencies like AzimuthLib across the entire Cosmic Series).*

**Typical Dependent Behavior:**

- Declare **Cosmic Vault** as a dependency.
- Include shared configuration and debug libraries directly from the Vault.
- Route diagnostics through Vault conventions.

**Why it matters:**
Stabilizes cross-mod expectations and drastically reduces maintenance fragmentation over time.
</details>

### 8) Shared Server Data Contracts (Faction Index API)

<details>
<summary><b>Click to expand details</b></summary>

**What it does:**
Provides universal, cached data payloads to the global `Server()` object to prevent expensive API loops across multiple mods. Features a rapid 15-second warm-up delay on initial server boot before falling back to a 5-minute refresh cycle to rapidly catch new galaxy generations.

**Current Contracts:**

- **Faction Index API:** Safely scans and caches active faction indices, perfectly preserving dynamically generated High-ID factions (Pirates, Xsotan, DLC).
  - `Server():getValue("factions")` (string): A comma-separated string containing the canonical list of active AI, player, and alliance faction indices. Consumer scripts must unpack this string into a table.
  - `Server():getValue("factions_ready")` (boolean): Safety flag indicating the indexer has completed its first warm-up cycle.
  - `Server():getValue("factions_count")` (number): The total number of indexed factions.
  - `Server():getValue("factions_last_refresh")` (number): The unpaused server runtime when the cache was last rebuilt.

**Why it matters:**
Prevents background scripts from repeatedly running expensive calculations (e.g., iterating through thousands of potential faction IDs) by providing a single, highly performant source of truth for all Cosmic mods.
</details>

### 9) Shared Dialogue API Contract

<details>
<summary><b>Click to expand details</b></summary>

**Primary path target:**

- `data/scripts/lib/cosmicvaultdialogue.lua`

**What it does:**
Provides a centralized registry for narrative mods (like **Cosmic Chronicles**) to safely store, filter, and retrieve contextual dialogue, rumors, and lore strings utilizing short-circuit evaluation for maximum performance.

**Core Methods:**

- `CosmicVaultDialogue.registerLine(entry)`: Registers a dialogue entry with a specific `category`, `text`, and optional contextual `conditions`.
- `CosmicVaultDialogue.getValidLine(category, currentContext)`: Safely parses the registered lines and returns a random valid string that perfectly matches the provided `currentContext` table.

**Supported Context Filters:**

- `minWarHeat`, `factionTrait`, `factionWealth`, `stationType`, `minDistanceToCenter`, `maxDistanceToCenter`, `minReputation`.

**Why it matters:**
Standardizes how narrative text is injected into the game. It allows multiple mods to contribute lore to the same ambient pools without overwriting each other, while ensuring dialogue strictly reacts to dynamic background simulations (like War Heat or Economy changes).
</details>

### 10) Shared Player Settings API

<details>
<summary><b>Click to expand details</b></summary>

**Primary path target:**

- `data/scripts/lib/cosmicvaultplayersettings.lua`

**What it does:**
A centralized API for storing and retrieving persistent player-specific UI settings, filter states, and preferences natively through the engine.

**Core Methods:**

- Operates directly via the highly performant `Player():getValue()` and `Player():setValue()` bindings.

**Why it matters:**
Completely eliminates the need for fragile, file-based I/O operations (like legacy `moddata.lua` scripts), which were a primary source of crashes on fresh dedicated servers. This ensures UI preferences and mod settings are saved flawlessly and persistently across sessions without risking file corruption.
</details>

---

## Integration Guidelines

### Integration Contract (For Dependent Mods)

When integrating with **Cosmic Vault**, dependent mods should generally follow these steps:

1. Declare dependency in `modinfo.lua`.
2. Use shared includes where available, e.g.:
   - `include("cosmicvaultconfig")`
   - `include("cosmicvaultdebug")`
   - `include("cosmicvaultdialogue")`
   - `include("cosmicvaultplayersettings")`
3. Follow Vault's debug prefix and diagnostics conventions.
4. Keep fallback behaviors safe if optional helpers are absent during transitional phases.

### Example Integration Pattern (High-Level)

A dependent mod can adopt this approach for safe integration:

1. Load the Vault helper using a guarded `include` (especially useful during migration windows).
2. Read shared configuration keys for debug and diagnostics behavior.
3. Route log outputs through the shared formatter and prefix.
4. Keep mod-specific, proprietary logic separated from shared helper internals.

*This ensures series-wide consistency while preserving the unique gameplay identity of each individual mod.*

---

## Ecosystem & Architecture

### Architecture Position in Cosmic Series

Think of **Cosmic Vault** as the structural base:

- **Foundation Layer:** Provides common building blocks (**Cosmic Vault**).
- **Gameplay Mods:** Consume those blocks to execute their own domain-specific logic (**Cosmic Overhaul**, **Cosmic War**, **Cosmic Starfall**, **Cosmic Chronicles**, etc.).

This strict separation improves:

- Maintainability.
- Onboarding speed for new modules.
- Cross-mod compatibility and reliability.

### Compatibility & Safety Notes

- **Cosmic Vault** is strictly an additive foundation, not a hard gameplay override system.
- Shared helper interfaces will remain conservative and backward-aware.
- Actively avoiding tight coupling that would force runtime failures in mixed mod stacks during update transition phases.

---

## Installation & Troubleshooting

### Installation

1. Place folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Enable **Cosmic Vault** in **Settings -> Mods**.
3. Restart Avorion when prompted.

### Troubleshooting Checklist

- [ ] Confirm **Cosmic Vault** is enabled in your mod load order.
- [ ] Confirm dependent mod dependency declarations match.
- [ ] Verify include paths for shared libs under `data/scripts/lib/`.
- [ ] Check logs for missing helper modules during migration windows.
- [ ] Ensure mod load order remains consistent in larger stacks.

---

## Development Status

**Lifecycle Status:** Foundational bootstrap + expansion phase.

### Already Established

- Base metadata and configuration structure.
- Server Data Contracts (Faction Index, Contextual Dialogue, Player Settings).
- Initial documentation baseline.

### Ongoing & Next Growth Targets

- Expand the `data/scripts/lib/` shared helper catalog.
- Standardize diagnostics helper interfaces.
- Provide stable helper APIs for dependent mods.
- Migrate duplicate utility patterns out of dependent mods and directly into the Vault.

**Cosmic Vault** is designed to become the stable utility backbone for the entire **Cosmic** series. Future progress heavily emphasizes robust shared libraries, cleaner cross-mod contracts, and reduced code duplication across all gameplay modules.


