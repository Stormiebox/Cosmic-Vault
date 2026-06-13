# 🌌 Cosmic Vault - Modder Guide

Welcome to the **Cosmic Vault API Guide**! This document provides technical instructions for modders who wish to safely hook into the Cosmic series' shared systems.

## 🏗️ Architecture & Best Practices

> [!WARNING]
> **Avorion Engine Limitations & The Highlander Pattern**
> When injecting your own mod logic into vanilla callbacks (like `player/init.lua`), **NEVER** overwrite the file entirely. Avorion strictly follows the Highlander Virtual File System, meaning whoever overwrites the file last wins, and breaks all other mods. You must wrap your code using the shim pattern!
> Furthermore, Avorion uses **synchronous single-threading** for its update loops. Running massive nested loops in `updateServer()` will cause catastrophic server TPS drops. Use the `CosmicVaultTask` API to offload this.

> [!CAUTION]
> **Network Desyncs & Math.Random**
> When syncing procedurally generated content across the client/server boundaries, absolutely **never** use `math.random()`. Doing so will cause severe multiplayer desyncs. Use Avorion's deterministic `random():getInt()` engine.

> [!CAUTION]
> **Callable Security Exploits**
> Any UI function triggered via `invokeServerFunction` must be explicitly registered using `callable()` in the server script. Missing this will not only break your UI in multiplayer, but failing to validate the incoming arguments can allow malicious clients to execute arbitrary remote code (ACE vulnerabilities).

---

## 📑 The API Library

### ⚙️ 1. Player Settings API (`cosmicvaultplayersettings.lua`)
Provides a robust, fail-safe wrapper around Avorion's `Player():setValue()` system, replacing direct `.json` file I/O which is highly prone to server locks.
```lua
local PlayerSettings = include("cosmicvaultplayersettings")
PlayerSettings.saveSetting("MyMod_FeatureEnabled", true)
local isEnabled = PlayerSettings.getSetting("MyMod_FeatureEnabled", true)
```

### 📰 2. Galactic News API (`cosmicvaultnews.lua`)
Inject breaking news into the centralized server-wide buffer, which broadcasts to all clients natively.
```lua
local CosmicVaultNews = include("cosmicvaultnews")
if onServer() then
    CosmicVaultNews.publishArticle({title="Crisis", category="War", content="Invasion!"})
end
```

### 🗃️ 3. Faction Index Registry (`cosmicvaultfaction.lua`)
A background cache of every generated faction in the galaxy, saving you from expensive cross-sector queries.
```lua
local function getRegisteredFactions()
    return loadstring(Server():getValue("CV_Faction_Index"))()
end
```

### 🖥️ 4. Cosmic UI Components (`cosmicvaultui.lua`)
Allows triggering cinematic screen overlays, banners, and creating flexible UI partitions without custom renderers.
```lua
local CosmicVaultUI = include("cosmicvaultui")
CosmicVaultUI.ShowCinematicBanner(Player(), "CRITICAL WARNING", ColorRGB(1, 0, 0), "data/sounds/siren.ogg", 5)
```

### ⏳ 5. Task Scheduler API (`cosmicvaulttask.lua`)
An Async Task Scheduler. Runs intensive Lua operations across multiple server ticks using Coroutines, completely preventing massive TPS drops.
```lua
local CosmicVaultTask = include("cosmicvaulttask")
CosmicVaultTask.RunAsync("MyHeavyScan", function()
    for i=1, 10000 do
        CosmicVaultTask.Yield() -- Pauses execution until the next Update tick
    end
end)
```

### 💾 6. Data Serialization API (`cosmicvaultdata.lua`)
Natively stores complex Lua tables onto Entities and applies tags for fast grouping and querying using `dkjson`.
```lua
local CosmicVaultData = include("cosmicvaultdata")
CosmicVaultData.SetTable(entity, "MyCustomData", {isBoss = true})
CosmicVaultData.AddTag(entity, "VIP_Target")
```

### ⚔️ 7. Arsenal API (`cosmicvaultarsenal.lua`)
Generates properly balanced, custom `Weapon`/`InventoryTurret` objects dynamically.
```lua
local CosmicVaultArsenal = include("cosmicvaultarsenal")
local turret = CosmicVaultArsenal.GenerateTurret({rarity = Rarity(RarityType.Legendary), weaponType = WeaponType.Bolter, damage = 500})
```

### 💹 8. Economy API (`cosmicvaulteconomy.lua`)
Reads live market data and natively broadcasts economic events.
```lua
local CosmicVaultEconomy = include("cosmicvaulteconomy")
CosmicVaultEconomy.TriggerMarketEvent("Processors", 150, -50, 10, "boom")
```

### 🏴‍☠️ 9. Encounter API (`cosmicvaultencounter.lua`)
Injects custom ambushes or anomalies natively when a player enters a sector.
```lua
local CosmicVaultEncounter = include("cosmicvaultencounter")
CosmicVaultEncounter.spawnAmbush(Faction().index, 5000, 3, nil, true)
```

### 📜 10. Mission API (`cosmicvaultmission.lua`)
Builds and posts standard bulletin boards natively.
```lua
local CosmicVaultMission = include("cosmicvaultmission")
local bulletin = CosmicVaultMission.createBulletin("Bounty Target", "Kill the pirate lord", "Hard", "150,000 Cr", "script.lua", {})
```

### 📈 11. Progression API (`cosmicvaultprogression.lua`)
Wraps native custom XP, skills, and perks.
```lua
local CosmicVaultProgression = include("cosmicvaultprogression")
CosmicVaultProgression.addXP(playerIndex, 50, "combat")
```

### 🎖️ 12. Fleet Command API (`cosmicvaultfleet.lua`)
Safe interface to issue vanilla AI orders without rewriting `craftorders.lua`.
```lua
local CosmicVaultFleet = include("cosmicvaultfleet")
CosmicVaultFleet.orderJump(entityId, 15, -20)
```

### 🧬 13. Goods API (`cosmicvaultgoods.lua`)
Natively injects custom trade goods.
```lua
local CosmicVaultGoods = include("cosmicvaultgoods")
CosmicVaultGoods.registerGood({name = "Cosmic Matter", price = 50000, volume = 5.0})
```

### 💎 14. Loot API (`cosmicvaultloot.lua`)
Drops custom loot natively.
```lua
local CosmicVaultLoot = include("cosmicvaultloot")
CosmicVaultLoot.dropCustomLoot(entityId, "good", "Cosmic Matter", 10)
```

### 🏗️ 15. Blueprint API (`cosmicvaultblueprint.lua`)
Spawns custom ships, stations, and turrets natively.
```lua
local CosmicVaultBlueprint = include("cosmicvaultblueprint")
local ship = CosmicVaultBlueprint.spawnShip(factionId, "data/plans/boss.xml", Matrix(), 5000)
```

### 🛰️ 16. Station Interaction API (`cosmicvaultstation.lua`)
Adds safe UI tabs to stations.
> [!TIP]
> Define your `initUI()` function **before** calling `CosmicVaultStation.injectInteraction()`.
```lua
local CosmicVaultStation = include("cosmicvaultstation")
CosmicVaultStation.injectInteraction("Talk to Mercenary", "Mercenary Guild", "onMercClicked")
```

### ⏰ 17. Global Events API (`cosmicvaultevents.lua`)
Manages galaxy-wide timers natively.
```lua
local CosmicVaultEvents = include("cosmicvaultevents")
CosmicVaultEvents.startEvent("xsotan_invasion", 3600)
```

### 🛡️ 18. Buffs API (`cosmicvaultbuffs.lua`)
Applies self-terminating buffs and tracks global faction-wide buff tiers.
```lua
local CosmicVaultBuffs = include("cosmicvaultbuffs")
CosmicVaultBuffs.applyBuff(entityId, "Velocity", 0.5, 30)
```

### 🔥 19. Combat & DoTs API (`cosmicvaultcombat.lua`)
Renders floating combat text and applies Damage-over-Time effects.
```lua
local CosmicVaultCombat = include("cosmicvaultcombat")
CosmicVaultCombat.applyDoT(targetId, sourceId, 500, 10, "Plasma Burn")
```

### 🔧 20. Config API (`cosmicvaultconfig.lua`)
Handles Server-to-Client mod configuration synchronization to securely prevent client manipulation of server economy rules.
```lua
local CosmicVaultConfig = include("cosmicvaultconfig")
local isHardMode = CosmicVaultConfig.get("HardMode")
```

### 🐛 21. Debug API (`cosmicvaultdebug.lua`)
Provides robust trace logging, error catching, and performance metrics.
```lua
local CosmicVaultDebug = include("cosmicvaultdebug")
CosmicVaultDebug.log("System initialized successfully in 12ms.")
```

### 💬 22. Dialogue API (`cosmicvaultdialogue.lua`)
A wrapper for native NPC conversation branching and callbacks without needing explicit file overrides.
```lua
local CosmicVaultDialogue = include("cosmicvaultdialogue")
CosmicVaultDialogue.showNode(Player(), "Welcome to the Forge. What do you require?")
```

### 🧩 23. Framework Core API (`cosmicvaultframework.lua`)
The internal state machine and bootstrapper for all vault APIs. Generally not interacted with directly, but handles dependency injection.
