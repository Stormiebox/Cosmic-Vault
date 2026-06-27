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

> [!TIP]
> **API Argument Validation & Docstrings**
> All Cosmic Vault API functions now require strict argument validation (`if not arg then return end`). When calling them, ensure you pass all required parameters as detailed by the generated docstrings in each API file.

> [!TIP]
> **Event Loop Throttling**
> When writing background simulation scripts (e.g., `updateServer` loops), **always** define `getUpdateInterval()` to throttle execution (e.g. `return 5.0`). Running logic every single frame (0s interval) should be strictly reserved for rendering UI fading or precise physical tracking.

> [!WARNING]
> **Common Native API Errors**
> Be highly cautious of incorrectly used API method names when using native C++ userdata objects.
> - **Relations:** `Faction` and `Player` userdata objects do NOT have a `setRelations()` or `changeRelations()` method. You must use the global `Galaxy():setFactionRelations()` and `Galaxy():changeFactionRelations()`.
> - **Stats & Entities:** Use `statModifier:addBaseMultiplier()` (not `modifyBaseMultiplier`). Use `entity:addMultiplyableBias()` (not `addMultiplyableFactor`).
> - **Sectors:** `Galaxy()` does NOT have a `setFaction()` or `tryUnloadSector()` method. Sector borders are natively controlled by the stations inside them.
> - **Blueprints:** `BlockPlan` does NOT have `plan:fromString()`. Use the global `LoadPlanFromString()`.
> Stormbox: This is from my personal findings and debugging often.
---

## 📑 The API Library

### ⚙️ 1. Player Settings API (`cosmicvaultplayersettings.lua`)
Provides a robust, fail-safe wrapper around Avorion's `Player():setValue()` system, replacing direct `.json` file I/O which is highly prone to server locks.
```lua
local PlayerSettings = include("cosmicvaultplayersettings")
PlayerSettings.set(Player(), "MyMod", "FeatureEnabled", true)
local isEnabled = PlayerSettings.get(Player(), "MyMod", "FeatureEnabled", true)
```

### 📰 2. Galactic News API (`cosmicvaultnews.lua`)
Inject breaking news into the centralized server-wide buffer, which broadcasts to all clients natively.
```lua
local CosmicVaultNews = include("cosmicvaultnews")
if onServer() then
    CosmicVaultNews.publishArticle({title="Crisis", category="War", content="Invasion!"})
end
```

### 🗃️ 3. Faction API & Custom Traits (`cosmicvaultfaction.lua`)
A robust background cache of generated factions, and a revolutionary API to bypass Avorion's hardcoded UI and inject **Custom Faction Traits** natively into the diplomacy window!

**Retrieving all factions:**
```lua
local function getRegisteredFactions()
    return loadstring(Server():getValue("CV_Faction_Index"))()
end
```

**Registering Custom Traits (Must be executed on the Client!):**
```lua
local cvf = include("cosmicvaultfaction")
cvf.registerCustomTrait(
    "industrial",
    "Industrial",
    {
        "Focuses heavily on resource production and trade.",
        "Defends mining operations aggressively."
    }
)
```

**Applying the trait to a Faction (Server-side):**
```lua
cvf.setTrait(faction.index, "industrial", 1.0)
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

### 💹 8. Economy API (`cosmicvaulteconomy.lua` & `cosmicvaultgoods.lua`)
Reads live market data, natively broadcasts economic events, and injects custom trade goods into the 5 global vanilla economy arrays dynamically!
```lua
local CosmicVaultGoods = include("cosmicvaultgoods")
local CosmicVaultEconomy = include("cosmicvaulteconomy")

-- Register custom goods securely
CosmicVaultGoods.registerGood({
    name = "Contraband", price = 50000, size = 2.5, illegal = true
})

-- Trigger events
CosmicVaultEconomy.TriggerMarketEvent("Processors", 150, -50, 10, "boom")

-- Register dynamic price fluctuations
CosmicVaultEconomy.registerPriceHook("Contraband", "mymod.lua", "onCalculateContrabandPrice")
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

### ⚖️ 11. Dynamic Scaling API (`cosmicvaultscaling.lua`)
Scans a sector to mathematically calculate the total combined Volume and Omicron (firepower) of all defending ships and stations. Useful for scaling spawned events to match player or AI fortress strength perfectly.
```lua
local CosmicVaultScaling = include("cosmicvaultscaling")
local stats = CosmicVaultScaling.calculateSectorDefenderStrength(enemyFactionIndex)
local params = CosmicVaultScaling.calculateInvaderSpawnParams(stats, baseShipVolume, 1.0) -- Scale to 100% of defenders
```

### 📈 12. Progression API (`cosmicvaultprogression.lua`)
Wraps native custom XP, skills, and perks.
```lua
local CosmicVaultProgression = include("cosmicvaultprogression")
CosmicVaultProgression.addXP(playerIndex, 50, "combat")
```

### 🎖️ 13. Fleet Command API (`cosmicvaultfleet.lua`)
Safe interface to issue vanilla AI orders without rewriting `craftorders.lua`.
```lua
local CosmicVaultFleet = include("cosmicvaultfleet")
CosmicVaultFleet.orderJump(entityId, 15, -20)
```

### 🧬 14. Goods API (`cosmicvaultgoods.lua`)
Natively injects custom trade goods.
```lua
local CosmicVaultGoods = include("cosmicvaultgoods")
CosmicVaultGoods.registerGood({name = "Cosmic Matter", price = 50000, volume = 5.0})
```

### 💎 15. Loot API (`cosmicvaultloot.lua`)
Drops custom loot natively.
```lua
local CosmicVaultLoot = include("cosmicvaultloot")
CosmicVaultLoot.dropCustomLoot(entityId, "good", "Cosmic Matter", 10)
```

### 🏗️ 16. Blueprint API (`cosmicvaultblueprint.lua`)
Spawns custom ships, stations, and turrets natively.
```lua
local CosmicVaultBlueprint = include("cosmicvaultblueprint")
local ship = CosmicVaultBlueprint.spawnShip(factionId, "data/plans/boss.xml", Matrix(), 5000)
```

### 🛰️ 17. Station Interaction API (`cosmicvaultstation.lua`)
Adds safe UI tabs to stations.
> [!TIP]
> Define your `initUI()` function **before** calling `CosmicVaultStation.injectInteraction()`.
```lua
local CosmicVaultStation = include("cosmicvaultstation")
CosmicVaultStation.injectInteraction("Talk to Mercenary", "Mercenary Guild", "onMercClicked")
```

### ⏰ 18. Global Events API (`cosmicvaultevents.lua`)
Manages galaxy-wide timers natively.
```lua
local CosmicVaultEvents = include("cosmicvaultevents")
CosmicVaultEvents.startEvent("xsotan_invasion", 3600)
```

### 🛡️ 19. Buffs API (`cosmicvaultbuffs.lua`)
Applies self-terminating buffs and tracks global faction-wide buff tiers.
```lua
local CosmicVaultBuffs = include("cosmicvaultbuffs")
CosmicVaultBuffs.applyBuff(entityId, "Velocity", 0.5, 30)
```

### 🔥 20. Combat & DoTs API (`cosmicvaultcombat.lua`)
Renders floating combat text and applies Damage-over-Time effects natively.
```lua
local CosmicVaultCombat = include("cosmicvaultcombat")
-- applyDoT(entityId, damageType, totalDamage, durationSeconds, sourceId)
CosmicVaultCombat.applyDoT(targetId, DamageType.Energy, 500, 10, sourceId)
```

### 🔧 21. Config API (`cosmicvaultconfig.lua`)
Handles Server-to-Client mod configuration synchronization to securely prevent client manipulation of server economy rules.
```lua
local CosmicVaultConfig = include("cosmicvaultconfig")
local isHardMode = CosmicVaultConfig.get("HardMode")
```

### 🐛 22. Debug API (`cosmicvaultdebug.lua`)
Provides robust trace logging, error catching, and performance metrics.
```lua
local CosmicVaultDebug = include("cosmicvaultdebug")
CosmicVaultDebug.log("System initialized successfully in 12ms.")
```

### 💬 23. Dialogue API (`cosmicvaultdialogue.lua`)
A wrapper for native NPC conversation branching and callbacks without needing explicit file overrides.
```lua
local CosmicVaultDialogue = include("cosmicvaultdialogue")
CosmicVaultDialogue.showNode(Player(), "Welcome to the Forge. What do you require?")
```

### 🗺️ 24. Territory API (`cosmicvaultterritory.lua`)
Safely manages mathematical territory expansion and station flips without triggering the "Sector Alive" performance trap. Includes native bindings to `CosmicVaultNews` and functions for background faction generation.

> [!NOTE]
> **Station Flip Queue:** Due to engine limits in Avorion 2.0+, stations in unloaded offline sectors cannot be physically flipped. The Territory API safely bypasses this by placing territory conquests into a global deferred queue. The actual station ownership transfer executes instantaneously the next time any player loads into that sector natively.

```lua
local CosmicVaultTerritory = include("cosmicvaultterritory")

-- Set a sector to be conquered by faction 2 from faction 3 after 60 minutes.
CosmicVaultTerritory.setContestedZone(x, y, 2, 3, 60)

-- Dynamically generate a new outpost or pirate base in empty space without crashing the server.
CosmicVaultTerritory.expandToSector(x, y, factionIndex, isPirate)
```

### 🧩 24. Framework Core API (`cosmicvaultframework.lua`)
The internal state machine and bootstrapper for all vault APIs. Generally not interacted with directly, but handles dependency injection.


---

### 🎮 25. Mod Configuration Menu (CCM) Keybind API (`ccm.lua` & `ccm_keycodes.lua`)
Provides a native, user-configurable keybind framework fully integrated into the UI.
```lua
local cvcfg = ccm.bind("CosmicVault")
if cvcfg.isKeyComboDown("hotkeyCodex") then
    -- Execute action when ALT+P (default) is pressed
end
```
You can register keybinds dynamically by using `type = "keybind"` in your `ccm.register` options array!

### 🌾 26. Economy Famine API (`cosmicvaulteconomy.lua`)
Exposes `addFamineScore` and `getFamineLevel` to track faction starvation, creating dynamic resource shortages and inflation across an entire empire's territory.
```lua
local CosmicVaultEconomy = include("cosmicvaulteconomy")
CosmicVaultEconomy.addFamineScore(factionIndex, 500)
local severity = CosmicVaultEconomy.getFamineLevel(factionIndex)
```

### 🌌 27. Anomalies API (`cosmicvaultanomalies.lua`)
Exposes logic for generating permanent, interactive points of interest natively.
```lua
local CosmicVaultAnomalies = include("cosmicvaultanomalies")
CosmicVaultAnomalies.spawnAnomaly(x, y, "Void_Rupture")
```

## 10. Library Development Best Practices & Rogue Globals
When building modular APIs or extending Cosmic Vault, you may create library files (`data/scripts/lib/*.lua`) that other scripts can `include()`. You **MUST** ensure that these library files do not define global Avorion engine callbacks (such as `function updateServer(...)` or `function getUpdateInterval(...)`).

Because of how Avorion's Virtual File System operates, when a script calls `include("yourlibrary")`, any global functions defined in that library are injected directly into the calling script's Lua VM. If the calling script also has an `updateServer()` loop, the library's update loop will overwrite it, causing impossible-to-debug logic failures.

**Correct Library Structure:**
```lua
local MyCustomLib = {}

function MyCustomLib.doSomething()
    -- Logic here
end

return MyCustomLib
```

Never append global VM hooks at the bottom of these files!
