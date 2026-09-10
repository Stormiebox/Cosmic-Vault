# 🌌 Cosmic Vault

*The foundational API library and core framework for the Cosmic Series.*

![Version](https://img.shields.io/badge/version-4.0.0-6f42c1?style=flat-square)
![Avorion](https://img.shields.io/badge/Avorion-1.0--5.0-2f81f7?style=flat-square)
![License](https://img.shields.io/badge/license-GPLv3-informational?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey?style=flat-square)
![Dependencies](https://img.shields.io/badge/dependencies-none-success?style=flat-square)

> [!TIP]
> New here? [`WIKI.md`](https://github.com/Stormiebox/Cosmic-Vault/wiki/Features) explains what each system does. [`MODDER_GUIDE.md`](https://github.com/Stormiebox/Cosmic-Vault/wiki/Modder%E2%80%90Guide) has the function signatures and code examples if you're building on top of the Vault.

## 📖 Overview

Cosmic Vault is the shared spine every other Cosmic mod builds on: libraries for the Cosmic Codex, unified UI components, asynchronous task scheduling, and secure client/server communication. It exists so the rest of the series doesn't reimplement the same helpers five times, and so modders extending the series never need a destructive hard override of a vanilla script.

**Current version: 4.0.0.** v3.5.0 was a stabilization release (permanent buffs that could never be removed, escort orders with no target, loot drops that dropped nothing, custom faction traits that never rendered, two anomaly types that spawned with no behavior attached, and more — see `Changelog.md`), and made every cross-mod hook `pcall`-guarded so Cosmic Vault runs standalone without the rest of the Core 4 installed. v3.6.0-v4.0.0 have been additive feature releases since — a UI Kit, a Settings Schema layer, Upgrade Categories, and (v4.0.0) a generic per-actor resource ledger, a relief-applied tracker, a passive-decay registry, a galactic hostility index reader, a faction dossier tooltip builder, an extended bulletin builder, and a new Faction Conflict Scoreboard — all built to support Cosmic War's v4.0.0 War Overhaul Update, all reusable by any Cosmic mod.

## ✨ Key Features

- **📚 Cosmic Codex API:** injects Vault content into the in-game encyclopedia.
- **🤝 Custom Faction Traits API:** custom traits rendered directly in the vanilla diplomacy UI.
- **📰 Galactic News API:** a global news buffer, with a `breaking` flag for interrupt-worthy events, that any Cosmic mod can publish to and read from.
- **🗺️ Territory Expansion API:** mathematical border control and lazy station materialization for AI faction expansion.
- **💰 Custom Economy Engine:** custom trade goods, dynamic price hooks, and per-faction famine tracking without touching vanilla background scripts.
- **⚡ Async Task Scheduler:** spreads heavy script work across ticks instead of stalling the server.
- **🖥️ Unified UI System:** cinematic banners, proportional splitters, and a shared configuration menu (CCM) other mods register into.
- **🔒 Security Layer:** validates server callbacks and uses deterministic RNG, closing off remote-execution exploits and multiplayer desyncs.
- **📒 Shared Resource Ledgers & Conflict Scoring:** a generic per-actor (Player or Alliance) resource ledger, a relief-applied tracker, a passive-decay registry, and a standalone faction conflict scoreboard, all purely additive.

## ⚙️ Requirements

- Avorion 1.0–5.0 (see `modinfo.lua`).
- No mod dependencies. Cosmic Vault is the foundation the rest of the series depends on, not the other way around.
- It is the mandatory core requirement for every other Cosmic Series mod (Cosmic Overhaul, Cosmic War, Cosmic Chronicles, Cosmic Ascendancy, Cosmic Starfall).

## 📥 Installation

1. Place the folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Enable **Cosmic Vault** in **Settings → Mods**.
3. Restart Avorion when prompted.

## 📚 Documentation

| Document | For | Covers |
|---|---|---|
| [`WIKI.md`](https://github.com/Stormiebox/Cosmic-Vault/wiki/Features) | Anyone curious how the Vault works | Full technical reference for every system the Vault exposes — what it does, which files implement it, what changed recently. |
| [`MODDER_GUIDE.md`](https://github.com/Stormiebox/Cosmic-Vault/wiki/Modder%E2%80%90Guide) | Modders building on top of the Vault | Function signatures and copy-pasteable code examples for every public API. |
| **Cosmic Codex** *(in-game)* | Players | Vault lore and mechanics, readable without leaving the game. |

---

<div align="center">

**🌌 Cosmic Vault** — part of the [Cosmic Series](https://github.com/Stormiebox) · built by **Stormbox**

</div>
