# ⚙️ Cosmic Vault - Detailed Features

Welcome to the **Cosmic Vault** official wiki! This page contains the full, detailed documentation for the shared foundation layer of the **Cosmic** mod series.

**Cosmic Vault** is intended to centralize reusable code, configuration patterns, and shared assets so other mods in the series can:

- Avoid duplicate implementations.
- Stay behavior-consistent.
- Integrate faster with lower maintenance costs.


### 11) Shared Modding APIs (Vanilla+)

<details>
<summary><b>Click to expand details</b></summary>

**What it does:**
A massive expansion introduced in v2.0.0, the Vault provides a complete suite of standalone APIs (Task Scheduling, Arsenal Generation, Entity Data Tagging, Cinematic UI, and Economy Hooks) designed explicitly to allow modders to create "Vanilla+" mechanics without ever having to use dangerous "hard overrides" on core Avorion scripts.

**Included Libraries:**
- `cosmicvaulttask.lua`: Lua Coroutine manager for running heavy operations over multiple server ticks without hanging the server.
- `cosmicvaultdata.lua`: Natively store complex JSON tables and Entity Tags directly into the Avorion engine via `dkjson`.
- `cosmicvaultui.lua`: Trigger highly immersive cinematic UI overlays, banners, and sounds on client screens effortlessly.
- `cosmicvaultnews.lua`: A centralized and validated global news broadcasting API for injecting custom faction and event articles natively into the bulletin systems.
- `cosmicvaultarsenal.lua`: Mathematical generator for spitting out perfectly balanced custom `Weapon` and `InventoryTurret` drops on the fly.
- `cosmicvaulteconomy.lua`: Natively read market data, trigger economic Booms and Crashes, and hook custom dynamic price multipliers securely across the entire galaxy.
- `cosmicvaultencounter.lua`: Inject custom ambushes, anomalies, or boss spawns safely when players enter sectors without touching `sectorspecifics.lua`.
- `cosmicvaultmission.lua`: Streamlined creation and injection of custom missions into native Bulletin Boards without overriding station logic. Features comprehensive UI-handling for `failMission` events and physical `grantItemReward` automation.
- `cosmicvaultprogression.lua`: Standardized custom XP, levels, and skill-tree perks synced securely across client and server.
- `cosmicvaultfleet.lua`: Safe command injection for pushing complex AI orders (patrol, escort, automated mining/salvaging) without hard overriding `craftorders.lua`.
- `cosmicvaultfaction.lua`: A revolutionary API to bypass Avorion's hardcoded UI and inject Custom Faction Traits natively into the diplomacy window, as well as safely mirror relationship changes to Player Alliances without crashing.
- `cosmicvaultgoods.lua`: Safely inject custom Trade Goods (with properties like illegal, dangerous) directly into the 5 global economy arrays without overwriting the hardcoded `goods.lua`.
- `cosmicvaultloot.lua`: Hook into native destruction sequences to drop custom loot and specifically spawn dynamic `SystemUpgradeTemplate` objects directly into space natively.
- `cosmicvaultblueprint.lua`: Safely load and dynamically spawn custom XML ships, stations, and custom turrets with native AI and crew generation.
- `cosmicvaultstation.lua`: Safely append custom dialogue or interaction tabs to vanilla stations cleanly, featuring custom maximum-distance overrides for UI security.
- `cosmicvaultevents.lua`: A server-safe timer for tracking galaxy-wide events (e.g. "Xsotan Invasions") that persist across server reboots.
- `cosmicvaultbuffs.lua`: Safely inject temporary stat modifiers (Speed, Shields, Damage) directly onto ships via tiny, self-terminating scripts. Allows persistent tracking of global faction-wide buff tiers across the galaxy, and features C++-safe `addPermanentBaseMultiplier` integrations.
- `cosmicvaultterritory.lua`: Native background mathematical border shifting and background physical station generation for native, dynamic AI faction expansion. Securely tracks absolute `startTime` for synchronized HUD integration across client bounds.
- `cosmicvaultcombat.lua`: Exposes `applyDoT` and native logic to render floating combat text for DOTs dynamically.
- `cosmicvaultscaling.lua`: Dynamic native OM/Volume math for spawning accurately scaled invasion fleets matching defender strength.
- `cosmicvaultanomalies.lua`: Seamless API to inject persistent, interactive points-of-interest (POIs) natively into sectors.
- `cv_weather_controller.lua`: Global Subspace Weather API allowing mods to natively trigger or clear localized environmental hazards (EMP storms, radiation, etc) combined with seamless UI integration via Avorion's native `addShipProblem()` warning system.
- `cv_weather_generator.lua`: Defines all standard weather hazards, mapping keys to native Avorion icons, descriptions, and dynamic `isShipPrepared` protection callbacks.
- `cosmicvaultconfig.lua`: Standardized global config bootloader ensuring that complex configuration states (such as metrics tracking) are safely loaded into server memory before logic executes.
- `cosmicvaultmetrics_server.lua`: Dedicated global telemetry script utilizing native engine `onPlayerLogIn` and `onSectorEntered` callbacks to securely trace tracking data without causing cross-entity routing crashes.

**Why it matters:**
Modders no longer need to destructively overwrite vanilla code (which causes huge mod conflicts). They can just drop in these APIs and call them directly, keeping their mods lightweight and 100% compatible with the rest of the community.
</details>

---

## 📑 Table of Contents

- [Mod Identity & Purpose](#mod-identity--purpose)
- [Core Design Principles](#core-design-principles)
- [Foundation Scope & Features](#foundation-scope--features)
- [Integration Guidelines](#integration-guidelines)
- [Ecosystem & Architecture](#ecosystem--architecture)
- [Installation & Troubleshooting](#installation--troubleshooting)
- [Development Status](#development-status)

---

## 🧬 Mod Identity & Purpose

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

## ⚙️ Foundation Scope & Features

### 📰 1) Galactic News API (Broadcasting Hub)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**
- `data/scripts/lib/cosmicvaultnews.lua`
- `data/scripts/server/cosmicvaultnews_server.lua`

**What it does:**
Acts as the central nervous system for galactic broadcasting. Any mod in the Cosmic series can use this API to instantly publish dynamic news articles to the global server buffer.

**Key Methods:**
- `CosmicVaultNews.publishArticle(article)`: Safely pipes a formatted article (title, category, content) into the server via the native `Server():sendCallback()` global event bus. If no author is provided, it automatically assigns one of 35 randomized reporter names to enhance immersion.
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

### 3) Shared Configuration Baseline (CCM)

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:**

- `ccm.lua`

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

### 🌐 8) Shared Server Data Contracts (Faction Index API)

<details>
<summary><b>Click to expand details</b></summary>

**What it does:**
Provides universal, cached data payloads to the global `Server()` object to prevent expensive API loops across multiple mods. Features a rapid 15-second warm-up delay on initial server boot before falling back to a 5-minute refresh cycle to rapidly catch new galaxy generations.

**Current Contracts:**

- **Faction Index API:** Safely scans and caches active faction indices, perfectly preserving dynamically generated High-ID factions (Pirates, Xsotan, DLC).
  - `Server():getValue("factions")` (string): A comma-separated string containing the canonical list of active AI faction indices (player and alliance factions are intentionally excluded, since consumers use this list for AI-targeting logic like famine wars and market events). Consumer scripts must unpack this string into a table.
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


### 11) Shared Modding APIs (Vanilla+)

<details>
<summary><b>Click to expand details</b></summary>

**What it does:**
A massive expansion introduced in v2.0.0, the Vault provides a complete suite of standalone APIs (Task Scheduling, Arsenal Generation, Entity Data Tagging, Cinematic UI, and Economy Hooks) designed explicitly to allow modders to create "Vanilla+" mechanics without ever having to use dangerous "hard overrides" on core Avorion scripts.

**Included Libraries:**
- `cosmicvaulttask.lua`: Lua Coroutine manager for running heavy operations over multiple server ticks without hanging the server.
- `cosmicvaultdata.lua`: Natively store complex JSON tables and Entity Tags directly into the Avorion engine via `dkjson`.
- `cosmicvaultui.lua`: Trigger highly immersive cinematic UI overlays, banners, and sounds on client screens effortlessly.
- `cosmicvaultarsenal.lua`: Mathematical generator for spitting out perfectly balanced custom `Weapon` and `InventoryTurret` drops on the fly.
- `cosmicvaulteconomy.lua`: Natively read market data and trigger economic Booms and Crashes that automatically link up to the Galactic News Network.

**Why it matters:**
Modders no longer need to destructively overwrite vanilla code (which causes huge mod conflicts). They can just drop in these APIs and call them directly, keeping their mods lightweight and 100% compatible with the rest of the community.
</details>

## 🔗 Integration Guidelines

### 🔗 Integration Contract (For Dependent Mods)

When integrating with **Cosmic Vault**, dependent mods should generally follow these steps:

1. Declare dependency in `modinfo.lua`.
2. Use shared includes where available, e.g.:
   - `include("cosmicvaultconfig")`
   - `include("cosmicvaultdebug")`
   - `include("cosmicvaultdialogue")`
   - `include("cosmicvaultplayersettings")`
3. Follow Vault's debug prefix and diagnostics conventions.
4. Keep fallback behaviors safe if optional helpers are absent during transitional phases.

### 🔗 Example Integration Pattern (High-Level)

A dependent mod can adopt this approach for safe integration:

1. Load the Vault helper using a guarded `include` (especially useful during migration windows).
2. Read shared configuration keys for debug and diagnostics behavior.
3. Route log outputs through the shared formatter and prefix.
4. Keep mod-specific, proprietary logic separated from shared helper internals.

*This ensures series-wide consistency while preserving the unique gameplay identity of each individual mod.*

---

## ⚙️ Ecosystem & Architecture

### 🏗️ Architecture Position in Cosmic Series

Think of **Cosmic Vault** as the structural base:

- **Foundation Layer:** Provides common building blocks (**Cosmic Vault**).
- **Gameplay Mods:** Consume those blocks to execute their own domain-specific logic (**Cosmic Overhaul**, **Cosmic War**, **Cosmic Starfall**, **Cosmic Chronicles**, etc.).

This strict separation improves:

- Maintainability.
- Onboarding speed for new modules.
- Cross-mod compatibility and reliability.

### 🛡️ Compatibility & Safety Notes

- **Cosmic Vault** is strictly an additive foundation, not a hard gameplay override system.
- Shared helper interfaces will remain conservative and backward-aware.
- Actively avoiding tight coupling that would force runtime failures in mixed mod stacks during update transition phases.

---

## 🛠️ Installation & Troubleshooting

### 🛠️ Installation

1. Place folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Enable **Cosmic Vault** in **Settings -> Mods**.
3. Restart Avorion when prompted.

### 🛠️ Troubleshooting Checklist

- [ ] Confirm **Cosmic Vault** is enabled in your mod load order.
- [ ] Confirm dependent mod dependency declarations match.
- [ ] Verify include paths for shared libs under `data/scripts/lib/`.
- [ ] Check logs for missing helper modules during migration windows.
- [ ] Ensure mod load order remains consistent in larger stacks.

---

## 📈 Development Status

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




## 🔗 Latest Additions & Integrations

- **Floating Combat Text & DoTs API**: Added `cosmicvaultcombat.lua` exposing `applyDoT` and native logic to render floating combat text for DOTs dynamically.
- **Permanent Buffs API**: Added `applyPermanentFactor` to `cosmicvaultbuffs.lua` to dynamically scale boss shields/damage directly via script natively.


---

## 🔗 Cosmic Series Integration & Audit 3.0 Updates
<details>
<summary><b>Click to expand</b></summary>

During the Cosmic Series Final QA Audit (v3.0+), several massive backend systems were standardized across all mods:

### 🌌 Cosmic Vault Synergy (Cross-Mod Engine)
- **Deep Economy Warfare:** `CosmicVaultEconomy` can natively trigger `CosmicWarBridge.forceDeclareWar()` when a faction's famine score exceeds 100, forcing starvation-driven invasions.
- **Faction Trait Scaling Integration:** `CosmicVaultScaling` dynamically reads `Cosmic War` diplomatic traits. If an entrenched (Fortified) faction is invaded, their calculated defensive volume and firepower are globally multiplied by `1.3x`.
- **Unified News API Framework:** Centralized and fortified `CosmicVaultNews` to securely capture and validate news broadcasts from `Cosmic Chronicles`, `Cosmic War`, and `Cosmic Overhaul`.

### 📖 Cosmic Codex Integration
All deep lore, stat blocks, and dynamic recipes have been fully integrated into the in-game **Cosmic Codex**. You no longer need to tab out of the game to read these features; they will natively update and unlock inside your Codex UI as you progress!

### 🔒 Network Safety & Anti-Cheat
- **Math.Random Fix:** I've systematically replaced all unstable Lua `math.random` calls with Avorion's deterministic `random():getInt()` generation sequence. This guarantees 100% synchronization on Multiplayer Dedicated Servers and prevents cascading desyncs during massive fleet spawns.
- **Callable Validation:** UI and background scripts have been fully hardened. Malicious clients can no longer spoof "free" remote calls; the server actively verifies execution contexts before processing any requests, sealing multiple Arbitrary Code Execution (ACE) vulnerabilities.

### 🛠️ Vanilla Bug Fixes
- **Scout Mission Fix:** I've patched a massive, long-standing vanilla bug where Scout Missions would completely skip and ignore Faction Headquarters sectors because the native dialogue trees were missing the template definition.

### 🛑 C++ Native Engine Safety
- **Strict API Compliance:** I've ran mass-audit over hundreds of Lua scripts using .py scripts to hunt down incorrectly used Avorion API Indexes where the Lua codebase attempted to call non-existent methods on native C++ userdata objects (e.g., `Entity`, `Galaxy`, `Player`).
- **Crash Prevention:** Over a dozen critical `attempt to index` bugs were patched out of the wild. Faction borders are now properly respected organically (instead of via force-sets), distance checks use the exact 3D bounding-box math, and stat/entity biases strictly use the native C++ `addMultiplyableBias` and `addBaseMultiplier` terminology.
</details>


---

### Cosmic Configuration Menu (CCM) & Keybinds
As of v3.0.0, the Cosmic Vault introduces a fully standalone, 3-column UI Cosmic Configuration Menu (CCM). Modders can effortlessly expose their settings and keybinds to players.
- **Dynamic Hotkeys:** Fully supports modifier keys (CTRL, ALT, SHIFT).
- **Intelligent Input Safeties:** The keybind engine tracks chat-open state via a verified Enter-toggle/Escape-close heuristic (Avorion exposes no direct textbox-focus API), securely preventing any hotkeys from triggering or bleeding through while a player is typing in the chat.
- **Clean Unbinding:** Players can seamlessly unbind their configured hotkeys using the `Delete` or `Backspace` keys, cleanly avoiding Avorion's hardcoded engine-level `Escape` behavior.
- **Reset Functionality:** Every single configuration option natively receives an `anticlockwise-rotation` reset button to instantly restore schema defaults.

## Faction Economy
Cosmic Vault now tracks faction 'Famine Scores'. If factions lose territory, they suffer extreme economic and military penalties.

## Sector Anomalies
Vault can generate interactable permanent POIs like Precursor Wrecks and Spatial Rifts.

## Synergy Update
- **Famine Relief Anomalies**: Added a mechanic where severely starving factions (100+ Famine Score) can dynamically spawn Famine Relief Caches. Players can interact with them to steal loot or donate it to instantly lower the famine score by 50 and gain 25,000 reputation.
- **Alliance PvP Repercussions:** Core faction relations logic natively supports mirroring reputation changes to the player's active Alliance. You can no longer swap to a personal ship to trigger hostilities without implicating your alliance.


## [New] Rift DLC Interoperability
- **Global Rift Escalation:** The Cosmic Vault now tracks global Rift Guardian kills and Depth 50+ successful extractions.
- **Galaxy-wide Threats:** As the global Escalation Level rises, severe vanilla Xsotan attack swarms have an increased chance to converge on all online players simultaneously.
