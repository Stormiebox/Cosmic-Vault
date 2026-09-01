# ⚙️ Cosmic Vault — Wiki

Technical reference for **Cosmic Vault**, the shared foundation layer of the **Cosmic** mod series. This document covers every system the Vault exposes: what it does, which files implement it, and what changed in the most recent stabilization pass (v3.5.0).

Cosmic Vault centralizes reusable code, configuration patterns, and shared assets so the other Cosmic mods can avoid duplicate implementations, stay behavior-consistent, and integrate without extra maintenance cost. If you're building a mod on top of these APIs rather than just reading about them, see `MODDER_GUIDE.md` instead — it has code examples and function signatures.

---

## 📑 Contents

- [Mod Identity & Purpose](#-mod-identity--purpose)
- [Core Design Principles](#core-design-principles)
- [Foundation Scope & Features](#-foundation-scope--features)
  1. [Galactic News API](#1-galactic-news-api)
  2. [Cosmic UI Proportional Splitters](#2-cosmic-ui-proportional-splitters)
  3. [Cosmic Configuration Menu & Keybinds](#3-cosmic-configuration-menu--keybinds)
  4. [Shared Utility / Library Hub](#4-shared-utility--library-hub)
  5. [Shared Diagnostics Pattern](#5-shared-diagnostics-pattern)
  6. [Shared Visual/Asset Layer](#6-shared-visualasset-layer)
  7. [Dependency Contract for the Cosmic Series](#7-dependency-contract-for-the-cosmic-series)
  8. [Faction Index API](#8-faction-index-api)
  9. [Dialogue API](#9-dialogue-api)
  10. [Player Settings API](#10-player-settings-api)
  11. [Vanilla+ Modding API Catalog](#11-vanilla-modding-api-catalog)
  12. [Cross-Mod Synergy & Series Integration](#12-cross-mod-synergy--series-integration)
- [Integration Guidelines](#-integration-guidelines)
- [Ecosystem & Architecture](#-ecosystem--architecture)
- [Installation & Troubleshooting](#-installation--troubleshooting)
- [Development Status](#-development-status)

---

## 🧬 Mod Identity & Purpose

**Cosmic Vault** is an infrastructure mod, not a gameplay mod. It focuses on:

- Shared utility libraries other Cosmic mods `include()` directly.
- Common debug and diagnostics conventions.
- Reusable, series-wide architectural patterns (Highlander-safe shims, namespace routing, safe includes).

It has no dependencies of its own beyond Avorion — every other Cosmic mod depends on it, not the other way around.

### Dependents

- **Cosmic Overhaul**, **Cosmic War**, **Cosmic Chronicles**, and **Cosmic Ascendancy** — the Core 4, which also require each other and are developed for cross-compatibility.
- **Cosmic Starfall** — an optional installment that requires only Cosmic Vault, not the Core 4.

---

## Core Design Principles

1. **Single source of truth.** Centralize shared helpers instead of reimplementing them per mod.
2. **Safe inclusion.** Every cross-mod `include()` that isn't guaranteed to exist is wrapped in `pcall`, so a missing sister mod degrades a feature instead of crashing the library.
3. **Consistent diagnostics.** One logging and debug-prefix convention across the whole series.
4. **Minimal duplication.** If two Cosmic mods need the same math or the same UI pattern, it belongs in the Vault.
5. **Backward compatibility.** Vault APIs are extended, not broken, across versions.

---

## ⚙️ Foundation Scope & Features

### 1) Galactic News API

**Files:** `data/scripts/lib/cosmicvaultnews.lua`, `data/scripts/server/cosmicvaultnews_server.lua`

Any mod in the Cosmic series can publish a news article to a global server-side buffer, which broadcasts to all connected clients for UI boards such as Cosmic Chronicles' Galactic News Board.

- `CosmicVaultNews.publishArticle(article)` takes `{title, content, category, breaking}`. `category` defaults to `"General"` and accepts any free-text value, since consuming UIs are expected to group categories themselves. As of v3.5.0, `breaking` is coerced to a real boolean (`article.breaking == true`) instead of trusting whatever truthy value a caller passed in, so a consuming UI can rely on the field's type when deciding whether to fire a banner or an interrupt-worthy chat alert. If no author is set, the server assigns one of 35 randomized reporter names.
- The server keeps the latest 30 articles and pushes `onCosmicVaultNewsUpdated` to clients whenever the buffer changes.
- `CosmicVaultNews.getPublishedNews()` was a documented stub through v3.4.x — it existed, but did nothing. v3.5.0 implemented it: called from a server-side script, it now reads the live article list straight out of `cosmicvaultnews_server.lua` via `Galaxy():invokeFunction`. It's still server-only; there's no synchronous client/server call in Avorion, so a client that needs the news list has to request a sync (`invokeServerFunction`) and receive it back through `invokeClientFunction`, the same pattern Cosmic Chronicles' News Board already uses.

### 2) Cosmic UI Proportional Splitters

**File:** `data/scripts/lib/cosmicui_proportionalsplitter.lua`

`CosmicUIVerticalProportionalSplitter()` and `CosmicUIHorizontalProportionalSplitter()` let a UI mix absolute pixel measurements with fluid percentage-based regions, replacing the need for legacy UI dependencies like AzimuthLib.

### 3) Cosmic Configuration Menu & Keybinds

**Files:** `data/scripts/lib/ccm.lua`, `data/scripts/lib/ccm_keycodes.lua`, `data/scripts/player/ui/cosmicconfigmenu.lua`

The CCM is a standalone, three-column (Label | Control | Reset) configuration UI that any Cosmic mod can register settings and hotkeys into.

- **Baseline controls:** `debugEnabled` (defaults on), `debugPrefix`, `diagnosticsEnabled`, `diagnosticsInterval`.
- **Hotkey capture:** full modifier support (Ctrl/Alt/Shift) via `ccm_keycodes.lua`.
- **Chat-focus safety:** Avorion exposes no direct textbox-focus API — there is no `checkInputFocus()` function anywhere in the engine, despite older versions of this menu gating hotkeys behind exactly that call. v3.5.0 replaced the dead no-op with a working heuristic: Enter toggles chat, Escape force-closes it, and a cursor-visibility fallback closes it automatically if the state gets stuck. Hotkeys no longer fire while a player is typing.
- **Unbinding:** players clear a bound key with `Delete` or `Backspace` rather than `Escape`, which Avorion reserves for closing the menu.
- **Reset buttons:** every option gets an `anticlockwise-rotation` button that restores its schema default.
- **Sister-mod configs:** `initialize()`/`fillTree()` pull in `cosmicoverhaulconfig`, `cosmicwarconfig`, and `cosmicascendancyconfig` so their settings appear in the same menu. As of v3.5.0 all four sister-config includes go through a shared `loadSisterConfigs()` helper that wraps each one in `pcall` — previously any install missing one of those three mods (e.g. Vault on its own) crashed the whole CCM UI the moment it opened.
- **Sync:** settings persist through `Player():getValue()`/`setValue()`, so they survive save reloads and stay identical across a multiplayer session instead of reverting to defaults.

### 4) Shared Utility / Library Hub

**Path:** `data/scripts/lib/`

Home for shared config adapters, debug/log wrappers, data-normalization helpers, and compatibility shims used by more than one Cosmic mod. Section 11 below catalogs everything currently in this directory.

### 5) Shared Diagnostics Pattern

Every Vault library that logs uses the same convention: a per-module debug prefix, opt-in verbosity through `cosmicvaultdebug.lua`, and periodic diagnostic snapshots where relevant. Keeping this consistent is what makes it possible to read a log from a mixed Cosmic-mod server without guessing which mod a given line came from.

### 6) Shared Visual/Asset Layer

**Path:** `data/textures/`

Reusable icons and textures shared across Cosmic mods, so dependent mods don't ship duplicate copies of the same art.

### 7) Dependency Contract for the Cosmic Series

Cosmic Vault is the formal dependency target every other Cosmic mod declares in its own `modinfo.lua`. A dependent mod is expected to:

- Declare Cosmic Vault as a dependency.
- Pull shared config and debug libraries from the Vault rather than reimplementing them.
- Route diagnostics through Vault conventions.

Cosmic Vault itself declares no dependencies other than Avorion — see `modinfo.lua`. Its `dependencies` table is entirely `incompatible = true` entries against a handful of unrelated Workshop mods (legacy overhaul frameworks and total-conversion mods such as Xavorion), not requirements.

### 8) Faction Index API

Caches active AI faction indices in `Server()` so background scripts don't re-scan thousands of potential faction IDs on every tick. Warms up 15 seconds after server boot, then refreshes every 5 minutes.

- `Server():getValue("factions")` — comma-separated string of active AI faction indices. Player and alliance factions are intentionally excluded; consumers use this list for AI-targeting logic (famine wars, market events) and have to unpack the string themselves.
- `Server():getValue("factions_ready")` — boolean, true once the first warm-up cycle finishes.
- `Server():getValue("factions_count")` — number of indexed factions.
- `Server():getValue("factions_last_refresh")` — unpaused server runtime at the last rebuild.

### 9) Dialogue API

**File:** `data/scripts/lib/cosmicvaultdialogue.lua`

A registry for narrative mods (Cosmic Chronicles in particular) to store and retrieve contextual dialogue, rumors, and lore strings.

- `CosmicVaultDialogue.registerLine(entry)` — registers a `category`, `text`, and optional `conditions`.
- `CosmicVaultDialogue.getValidLine(category, currentContext)` — returns a random line whose conditions match the given context.
- **Supported context filters:** `minWarHeat`, `maxWarHeat`, `factionTrait`, `factionWealth`, `stationType`, `minDistanceToCenter`, `maxDistanceToCenter`, `minReputation`, `maxReputation`.

### 10) Player Settings API

**File:** `data/scripts/lib/cosmicvaultplayersettings.lua`

Stores per-player UI settings, filter states, and preferences through `Player():getValue()`/`setValue()`, replacing fragile file-based `.json` storage as a source of settings loss and corruption on dedicated servers.

**v3.5.0:** `get()`/`set()` called those bindings with no `onServer()` guard. `Player():getValue()`/`setValue()` are server-only — any client-side caller (a HUD widget built on this API, for instance) crashed with `invalid userobject of type Player`. Both functions now bail out safely on the client.

---

### 11) Vanilla+ Modding API Catalog

The Vault's largest surface: standalone APIs for task scheduling, item generation, data tagging, cinematic UI, economy hooks, and more, built so mods never need a destructive hard override of a vanilla script. Every file below lives in `data/scripts/lib/` unless noted otherwise.

- **`cosmicvaulttask.lua`** — coroutine-based scheduler for spreading heavy operations across multiple server ticks instead of stalling one frame.
- **`cosmicvaultdata.lua`** — stores structured Lua tables on entities via `dkjson`, plus tag-based grouping and querying.
- **`cosmicvaultui.lua`** — cinematic banners, popups, and sounds on the client. **v3.5.0:** the fallback `addScriptOnce("cosmicvaultcinematic.lua")` call (used only when a player is somehow missing the script) used a bare filename instead of the full `data/scripts/...` path `addScriptOnce` requires to resolve through the VFS, so it silently failed to attach. Fixed across all three call sites.
- **`cosmicvaultnews.lua`** / **`cosmicvaultnews_server.lua`** — see section 1.
- **`cosmicvaultarsenal.lua`** — generates balanced custom `Weapon`/`InventoryTurret` objects. **v3.5.0:** `GenerateTurret` used to write `rarity`/`material` onto the `InventoryTurret` object, both of which are read-only there, so the engine silently discarded every write. Both now write to the `Weapon` object instead, where they're genuinely writable. **Known limitation:** `config.weaponType` still has no effect on the generated weapon's actual damage type or behavior — the field isn't wired to anything the engine reads, and giving a weapon a real per-type identity needs the same manual physics setup vanilla's own `weapongenerator.lua` does (`setProjectile()`/`setBeam()`, `fireDelay`, `pvelocity`, etc.), which this helper doesn't implement.
- **`cosmicvaulteconomy.lua`** — reads live market data, triggers economic booms/crashes, tracks per-faction Famine Score (0 = normal, 1-100 = struggling, 100+ = famine), and exposes `registerPriceHook` for dynamic price fluctuations. **v3.5.0:** the unguarded `include("cosmicwarbridge")` at module load meant any install running Vault without Cosmic War (or Vault + Overhaul only) crashed the whole economy library the instant anything included it, since Vault declares no dependency on War. Now soft-included via `pcall`.
- **`cosmicvaultgoods.lua`** — registers custom trade goods (with flags like `illegal`/`dangerous`) into the five vanilla economy arrays; `volume` aliases to `size` in `registerGood()`.
- **`cosmicvaultencounter.lua`** — injects custom ambushes, anomalies, or boss spawns on sector entry without touching `sectorspecifics.lua`.
- **`cosmicvaultmission.lua`** — builds and posts bulletin-board missions, with `failMission()` for UI-handled failure and `grantItemReward()` for physical item payouts.
- **`cosmicvaultprogression.lua`** — custom XP, levels, and skill-tree perks synced across client and server. **v3.5.0:** same client-crash class as the Player Settings API above — `getXP`/`hasPerk` now guard against being called on the client.
- **`cosmicvaultfleet.lua`** — pushes AI orders (patrol, escort, mine, salvage) without rewriting `craftorders.lua`. **v3.5.0:** `orderEscort` passed a plain Lua string where `OrderChain.addEscortOrder` expects a raw `Uuid` (it calls `.string` on the argument internally); indexing `.string` on an already-stringified id resolves through Lua's string metatable to `nil`, so every escort order's target silently came back empty — ships accepted the order but never tracked anything. Now passes the raw `Uuid`.
- **`cosmicvaultfaction.lua`** — custom faction traits rendered in the vanilla diplomacy window, plus relation changes that mirror to a player's alliance. **v3.5.0:** the diplomacy shim hooked `Diplomacy.updateFactionInformation`, a function name that has never existed in vanilla `diplomacy.lua`. The real trait-rendering function is `Diplomacy:updateTraits(faction)` — every custom trait registered since this API launched in v3.0.0 has been computed correctly and simply never drawn. Re-pointed at the real function.
- **`cosmicvaultframework.lua`** — internal bootstrapper the other libraries build on: module registration, `assertType()`, `safeNumber()`/`safeBool()` coercion, `requireCompat()`. Not usually called directly by dependent mods.
- **`cosmicvaultloot.lua`** — drops custom cargo, weapons, turrets, or system upgrades via `dropCustomLoot()`. **v3.5.0:** `Sector:dropCargo/dropTurret/dropUpgrade` strictly expect `nil | Faction` in their reservation slots, but this call was passing a raw faction-index integer (or `0`). The `"good"` branch also had `amount` and a literal `0` swapped into the wrong positional argument slots, so every custom good drop requested zero units regardless of what the caller asked for. Both bugs are fixed; `owner` is now wrapped in `Faction(owner)`.
- **`cosmicvaultblueprint.lua`** — spawns custom ships, stations, and (in principle) turrets from XML plans. **v3.5.0** fixed two guaranteed crashes: `spawnShip`'s volume-scaling path called `plan:scale(aNumber)`, but `BlockPlan:scale()` takes a `vec3`, not a number, so every caller that passed the documented `volume` argument (including the Modder Guide's own example) crashed immediately; and both `spawnShip`/`spawnStation` called `ShipUtility.addMinimumCrew(...)`, a function that has never existed in `shiputility.lua`. Volume scaling now passes `vec3(factor)`, and crew is set directly via `ship.crew = ship.minCrew`. **`createTurretFromPlan` remains not implemented** — `InventoryTurret.rarity`/`.material`/`.weaponPrefix` are all read-only and there's no `customTurretDesign` field anywhere in the engine, so there's no way to build a turret from a block Plan at all. Since nothing in the Cosmic series calls it, it now logs a clear error and returns `nil` instead of silently returning an unconfigured default.
- **`cosmicvaultstation.lua`** — safely appends dialogue or interaction tabs to vanilla stations, with `maxDistance` overrides for interaction range.
- **`cosmicvaultevents.lua`** — persistent galaxy-wide timers (e.g. tracking an ongoing "Xsotan Invasion") that survive server reboots.
- **`cosmicvaultbuffs.lua`** — temporary self-terminating stat buffs, permanent multipliers, and global per-faction buff tiers. **v3.5.0 fixed two long-standing bugs:** `removePermanentFactor`/`removePermanentBaseMultiplier` called `entity:removeMultiplyableBias`/`entity:removeBaseMultiplier`, neither of which exists — only the universal `entity:removeBonus(key)` does — and the corresponding `apply*`/`add*` functions discarded the bonus key the engine returns, so there was nothing to pass to `removeBonus` even after fixing the method name. Permanent buffs could never be removed and stacked indefinitely on reapplication; the API now tracks the bonus key per entity/stat in memory so add/remove/reapply is idempotent. Separately, `clearBuffs` looped `while entity:hasScript(...) do entity:removeScript(...) end` bounded by a manual 100-iteration safety counter; `removeScript` is deferred, so `hasScript` never reflected the removal within the same tick, and the loop always ran its full 100 iterations no matter how many buff scripts actually existed. Replaced with a single snapshot of `entity:getScripts()`.
- **`cosmicvaultcombat.lua`** — `applyDoT()` plus native floating combat text rendering for damage-over-time effects.
- **`cosmicvaultscaling.lua`** — computes total defender Volume/Omicron in a sector via `calculateSectorDefenderStrength()`, for scaling invasions or events to match defender strength. Hard-capped at 500,000,000 total volume (uncapped values previously crashed shipyard generation).
- **`cosmicvaultanomalies.lua`**, **`data/scripts/entity/cv_anomaly_rift.lua`**, **`data/scripts/entity/cv_anomaly_wreck.lua`** — spawns persistent, interactive points of interest. **v3.5.0 implemented both entity scripts.** `spawnAnomaly`'s `"SpatialRift"` and `"PrecursorWreck"` branches have called `addScriptOnce()` against these two files since the API launched in v3.0.0, but neither file existed anywhere in the codebase — spawned rifts and wrecks sat in the sector with no attached behavior at all. Both now offer a one-time Salvage/Channel interaction (built on the same `ScriptUI():registerInteraction()` + `callable()` RPC pattern vanilla's own `cargostash.lua` uses) that drops a scaled credit/resource reward, with a chance at a bonus turret or system upgrade, then removes the interaction while leaving the entity itself behind as a permanent landmark.
- **`cosmicvaultweather.lua`** / **`server/cosmicvaultweather_server.lua`** — the trigger API: `triggerStorm(x, y, stormType, duration)`, `clearStorm(x, y)`, `getWeatherAt(x, y)`. **v3.5.0:** the server half had no `-- namespace` pragma and used a plain local table, so `Galaxy():invokeFunction()` — the only way the client-facing wrapper can reach it — had no name to resolve any of the three calls against. The entire trigger API was dead from the moment it shipped. Fixed by adding the missing namespace pragma.
- **`sector/cv_weather_controller.lua`** — the sector-attached hazard script itself; attach with `Sector():addScriptOnce("data/scripts/sector/cv_weather_controller.lua", stormType, duration)`, never a manual `addScript()`, or restarts will duplicate the hazard.
- **`cosmicvaultweatherdictionary.lua`** — hazard definitions (Ion Storm, Dark Matter Fog, Solar Flare, etc.), mapped to native icons, descriptions, and `isShipPrepared()` protection callbacks. **v3.5.0:** the Solar Flare `isShipPrepared` check read `block.volume` on a `BlockPlanBlock`, a property that doesn't exist there — reading an undefined property on engine userdata throws a fatal exception rather than returning `nil`, so any ship carrying Trinium-or-above blocks crashed the weather tick the first time it ran. Volume is now derived from `block.box.size`.
- **`cosmicvaultconfig.lua`** — server-to-client configuration sync bootloader; ensures config state is loaded before dependent logic runs.
- **`cosmicvaultdebug.lua`** — shared logging: `log()`, `info()`, `warn()`, `error()`, all namespaced per calling module.
- **`server/cosmicvaultmetrics_server.lua`** — telemetry via native `onPlayerLogIn`/`onSectorEntered` callbacks.
- **`server/cosmicvaultriftescalation_server.lua`** — tracks global Rift Guardian kills and Depth 50+ extractions for the Rift DLC escalation system (see section 12).
- **`player/cosmicvaultcodex.lua`**, **`player/codex/infoCv.lua`** — injects Cosmic Vault's own explanatory pages ("What is Cosmic Vault?") into the in-game Cosmic Codex UI. **v3.5.0:** `onCosmicCodexGatherData` called `include("player/codex/infoCv")`, a subdirectory-qualified path, but `include()` only searches `data/scripts/lib/` by default without the `package.path` mutation vanilla's own subdirectory includes require. Every Codex data-gather request threw `module not found`, so these pages never actually loaded. Fixed by adding the missing `package.path` entry at file scope.

### 12) Cross-Mod Synergy & Series Integration

How the Vault's systems talk to the rest of the Core 4 when those mods are installed alongside it. Every hook in this section degrades gracefully when the other mod is absent — see the compatibility note below.

- **Deep Economy Warfare:** `CosmicVaultEconomy` can trigger `CosmicWarBridge.forceDeclareWar()` when a faction's Famine Score exceeds 100, turning sustained famine into starvation-driven invasions.
- **Faction trait scaling:** `CosmicVaultScaling` reads Cosmic War's diplomatic traits. An entrenched (Fortified) defending faction gets its calculated defensive volume and firepower multiplied by 1.3x.
- **Alliance PvP mirroring:** `CosmicVaultFaction.changeRelations` mirrors reputation shifts to a player's active Alliance, so switching to a personal ship no longer bypasses alliance-wide consequences for hostile actions.
- **Unified News:** `CosmicVaultNews` accepts and validates broadcasts from Cosmic Chronicles, Cosmic War, and Cosmic Overhaul through the same API described in section 1.
- **Famine Relief Anomalies:** severely starving factions (Famine Score 100+) can spawn a Famine Relief Cache in their territory. Players who interact with it can loot it or donate it, instantly reducing the famine score by 50 and granting 25,000 reputation. Spawning the cache attaches `cc_blackbox.lua`, a file that only exists in Cosmic Chronicles; **v3.5.0** wrapped that attach in `pcall` so a Vault install without Chronicles (Vault + Starfall, say) doesn't fail every time a faction hits Famine Score 100.
- **Rift DLC interoperability:** the Vault tracks global Rift Guardian kills and Depth 50+ successful extractions. As the resulting Escalation Level rises, vanilla Xsotan attack swarms gain an increased chance to converge on all online players simultaneously.
- **Codex integration:** deep lore, stat blocks, and dynamic recipe data across the series live in the in-game Cosmic Codex rather than external wiki pages, so players can read them without leaving the game.

**Compatibility:** as of v3.5.0, every `include()` that reaches into a sister mod's files — the Cosmic War bridge, the three sister config menus, and Chronicles' `cc_blackbox.lua` — is wrapped in `pcall`. Cosmic Vault runs standalone; it simply skips the cross-mod features whose target mod isn't installed instead of crashing.

---

## 🔗 Integration Guidelines

### Integration Contract (For Dependent Mods)

1. Declare the dependency in `modinfo.lua`.
2. Use shared includes where available, e.g. `include("cosmicvaultconfig")`, `include("cosmicvaultdebug")`, `include("cosmicvaultdialogue")`, `include("cosmicvaultplayersettings")`.
3. Follow the Vault's debug-prefix and diagnostics conventions.
4. Keep fallback behavior safe if an optional helper is absent during a migration window.

### Example Integration Pattern

1. Load the Vault helper with a guarded `include`, especially during migration windows.
2. Read shared configuration keys for debug and diagnostics behavior.
3. Route log output through the shared formatter and prefix.
4. Keep mod-specific logic separated from shared helper internals.

This keeps series-wide consistency while preserving each mod's own gameplay identity.

---

## ⚙️ Ecosystem & Architecture

### Architecture Position in the Cosmic Series

Cosmic Vault is the structural base: it provides common building blocks, and the gameplay mods (Cosmic Overhaul, Cosmic War, Cosmic Chronicles, Cosmic Ascendancy, Cosmic Starfall) consume them to run their own domain-specific logic. That separation is what keeps maintenance, onboarding, and cross-mod compatibility manageable as the series grows.

### Compatibility & Safety Notes

- Cosmic Vault is strictly additive. It never hard-overrides a vanilla gameplay script.
- Shared interfaces are extended, not broken, across versions.
- Every cross-mod include is guarded (see section 12), so a mixed or partial install degrades a feature instead of crashing.

### Network Safety

- **Deterministic RNG:** background simulation code (ambush spawns, escalation ticks) uses Avorion's own `random():getInt()` rather than Lua's `math.random()`, which is not synchronized across client and server and causes desyncs the moment two peers disagree on a spawn seed.
- **Callable validation:** every UI function reachable from a client goes through `callable()` registration and server-side argument validation, so a malicious or malformed client request gets rejected instead of executed.

---

## 🛠️ Installation & Troubleshooting

### Installation

1. Place the folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Enable **Cosmic Vault** in **Settings → Mods**.
3. Restart Avorion when prompted.

### Troubleshooting Checklist

- [ ] Confirm Cosmic Vault is enabled in your mod load order.
- [ ] Confirm dependent mods' declared dependency versions match what's installed.
- [ ] Verify `include()` paths for shared libs under `data/scripts/lib/`.
- [ ] Check logs for missing helper modules if you're running a partial Cosmic install.
- [ ] Keep mod load order consistent, especially in larger stacks.

---

## 📈 Development Status

Cosmic Vault's foundational API surface is complete: every system in section 11 has existed since v3.0.0 or earlier. v3.5.0 is a stabilization release, not a feature release — it closes out a set of bugs that had been sitting in the library since their respective introductions, several dating back to v3.0.0, including buffs that could never be removed, escort orders with no target, loot drops that dropped nothing, turret generation that silently discarded its own arguments, and two anomaly types that had never actually worked. It also makes the Vault genuinely standalone: every include that reaches into a sister mod's files is now `pcall`-guarded, so installing Cosmic Vault without the rest of the Core 4 no longer crashes it.

Ongoing work is bugfix passes and documentation upkeep as the Core 4 mods continue building on these APIs, rather than net-new Vault features.
