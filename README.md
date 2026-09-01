# 🌌 Cosmic Vault

*The foundational API library and core framework for the Cosmic Series.*

## 📖 Overview

Cosmic Vault is the shared spine every other Cosmic mod builds on: libraries for the Cosmic Codex, unified UI components, asynchronous task scheduling, and secure client/server communication. It exists so the rest of the series doesn't reimplement the same helpers five times, and so modders extending the series never need a destructive hard override of a vanilla script.

**Current version: 3.5.0** — a stabilization release. It fixes a long list of bugs that had shipped since earlier versions (permanent buffs that could never be removed, escort orders with no target, loot drops that dropped nothing, custom faction traits that never rendered, two anomaly types that spawned with no behavior attached, and more — see `Changelog.md` for the full list), and makes every cross-mod hook `pcall`-guarded so Cosmic Vault runs standalone without the rest of the Core 4 installed.

## ✨ Key Features

- **📚 Cosmic Codex API:** injects Vault content into the in-game encyclopedia.
- **🤝 Custom Faction Traits API:** custom traits rendered directly in the vanilla diplomacy UI.
- **📰 Galactic News API:** a global news buffer, with a `breaking` flag for interrupt-worthy events, that any Cosmic mod can publish to and read from.
- **🗺️ Territory Expansion API:** mathematical border control and lazy station materialization for AI faction expansion.
- **💰 Custom Economy Engine:** custom trade goods, dynamic price hooks, and per-faction famine tracking without touching vanilla background scripts.
- **⚡ Async Task Scheduler:** spreads heavy script work across ticks instead of stalling the server.
- **🖥️ Unified UI System:** cinematic banners, proportional splitters, and a shared configuration menu (CCM) other mods register into.
- **🔒 Security Layer:** validates server callbacks and uses deterministic RNG, closing off remote-execution exploits and multiplayer desyncs.

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

- `WIKI.md` — full technical reference for every system the Vault exposes.
- `MODDER_GUIDE.md` — API signatures and code examples for modders building on top of the Vault.
- The in-game **Cosmic Codex** also carries Vault lore and mechanics for players who never leave the game.
