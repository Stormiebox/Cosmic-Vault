# Cosmic Vault - Modder Guide

Welcome to the **Cosmic Vault API Guide**! This document provides technical instructions for modders who wish to safely hook into the Cosmic series' shared systems.

## 1. Player Settings API
The `cosmicvaultplayersettings.lua` library provides a robust, fail-safe wrapper around Avorion's `Player():setValue()` system. It replaces direct `.json` file I/O (which is highly prone to server locks and sandboxing crashes on the client) with Avorion's native database.

### Usage
```lua
local PlayerSettings = include("cosmicvaultplayersettings")

-- To save a setting from the client (Requires invokeServerFunction)
PlayerSettings.saveSetting("MyMod_FeatureEnabled", true)

-- To retrieve a setting (Safe on client or server)
local isEnabled = PlayerSettings.getSetting("MyMod_FeatureEnabled", true) -- Second arg is the default value
```

## 2. Galactic News API
The `cosmicvaultnews.lua` API allows any mod to permanently inject breaking news into the centralized server-wide buffer. Articles are automatically broadcast to all clients and natively appear in the `Cosmic Chronicles` Galactic News Tab.

### Usage
```lua
local CosmicVaultNews = include("cosmicvaultnews")

-- Publish an article (Server-side only)
if onServer() then
    local myArticle = {
        title = "Massive Resource Shortage",
        category = "Trade Crisis",
        content = "The local faction is experiencing a severe deficit of Ogonite. Traders are rushing to exploit the margins."
    }
    CosmicVaultNews.publishArticle(myArticle)
end
```
*Note: The server automatically caps the buffer at the latest 30 articles.*

### Real-Time Client Synchronization
The server broadcasts `onCosmicVaultNewsUpdated` locally to all connected clients. You can register for this callback in your UI script to refresh your displays seamlessly without requiring players to reopen the window.
```lua
if onClient() then
    Player():registerCallback("onCosmicVaultNewsUpdated", "onNewsReceived")
end
```

### Architecture Safety (Global Event Bus & VM Deadlocks)
Internally, the `CosmicVaultNews.publishArticle()` API securely routes all incoming articles through Avorion's native global event bus via `Server():sendCallback()`. This bypasses strict Lua VM sandbox limits and prevents missing API errors (such as attempting to call `invokeFunction` directly on the Server object). 
Furthermore, it decouples the incoming publication request from the outgoing client broadcast. Rather than executing an immediate synchronous `invokeClientFunction` (which causes `EXCEPTION_ACCESS_VIOLATION` VM deadlocks if the original stack was locked by another callback), it flags an internal `needsPlayerNotification` variable. The engine safely triggers the client broadcast dynamically during the next native `updateServer()` tick. Modders do not need to manage this decoupling; the Vault handles it transparently.


## 3. Faction Index Registry
The `cosmicvaultfactionindex.lua` background script crawls the galaxy every 5 minutes and caches every generated faction into a highly performant `Server()` key-value store. This prevents expensive, laggy cross-sector queries.

### Usage
You can retrieve the table of all known factions natively via Server values:
```lua
local function getRegisteredFactions()
    local encoded = Server():getValue("CV_Faction_Index")
    if encoded then
        -- Returns an array of Faction Index IDs
        return loadstring(encoded)() 
    end
    return {}
end
```

## 4. Cosmic UI Components
The `cosmicui_proportionalsplitter.lua` library adds highly flexible proportional UI splitters previously locked behind legacy libraries. This allows you to mix absolute pixel padding with fractional percentage elements.

### Usage
```lua
include("cosmicui_proportionalsplitter")

-- Create a UI that has a fixed 15px element, a 20px element, 50% of the remaining space, and a 25px element.
local partitions = CosmicUIHorizontalProportionalSplitter(Rect(window.size), 10, 10, {15, 20, 0.5, 25})

local myLabel = window:createLabel(partitions[1], "Fixed 15px", 14)
local myMap = window:createMap(partitions[3]) -- Uses 50% of screen
```

## Compliance Notice: init.lua Wrappers
When injecting your own mod logic into vanilla callbacks (like `player/init.lua`), **NEVER** overwrite the file entirely. You must wrap your code to preserve the Highlander Virtual File System.

**Example of Safe Injection:**
```lua
local mymod_old_init = initialize
function initialize(...)
    if mymod_old_init then mymod_old_init(...) end

    -- Your custom init logic here
    if onServer() then
        Player():addScriptOnce("data/scripts/player/mymod.lua")
    end
end
```


## 5. Cosmic Vault Task API
The `cosmicvaulttask.lua` library provides an Async Task Scheduler. It allows modders to run intensive Lua operations across multiple server ticks using Coroutines, completely preventing massive TPS drops or server hangs.

### Usage
```lua
local CosmicVaultTask = include("cosmicvaulttask")

CosmicVaultTask.RunAsync("MyHeavyScan", function()
    for i=1, 10000 do
        -- Do heavy math
        CosmicVaultTask.Yield() -- Pauses execution until the next Update tick
    end
end)
```
*(Note: To use this natively, you must call `CosmicVaultTask.Update(timeStep)` in your own server update loop.)*

## 6. Cosmic Vault Data API
The `cosmicvaultdata.lua` library provides a native way to store complex Lua tables onto Entities, and apply tags for fast grouping and querying, completely natively without overriding vanilla scripts. It uses `dkjson` for safe serialization.

### Usage
```lua
local CosmicVaultData = include("cosmicvaultdata")

-- Store a table on an entity
CosmicVaultData.SetTable(entity, "MyCustomData", {isBoss = true, phase = 2})

-- Retrieve it
local data = CosmicVaultData.GetTable(entity, "MyCustomData")

-- Tags
CosmicVaultData.AddTag(entity, "VIP_Target")
local targets = CosmicVaultData.GetEntitiesByTag(Sector(), "VIP_Target")
```

## 7. Cosmic Vault Arsenal API
The `cosmicvaultarsenal.lua` library provides mathematical generators to spit out properly balanced, custom `Weapon`/`InventoryTurret` objects dynamically for loot drops, custom enemies, or missions.

### Usage
```lua
local CosmicVaultArsenal = include("cosmicvaultarsenal")

local turret = CosmicVaultArsenal.GenerateTurret({
    rarity = Rarity(RarityType.Legendary),
    weaponType = WeaponType.Bolter,
    damage = 500,
    color = ColorRGB(1, 0, 0)
})
```

## 8. Cosmic Vault UI API (Cinematic)
The `cosmicvaultui.lua` library allows modders to easily trigger cinematic screen overlays and banners for immersive events without writing custom UI renderers.

### Usage
```lua
local CosmicVaultUI = include("cosmicvaultui")
-- Triggers a 5-second red banner on the player's screen with a sound effect
CosmicVaultUI.ShowCinematicBanner(Player(), "CRITICAL WARNING", ColorRGB(1, 0, 0), "data/sounds/siren.ogg", 5)
```

## 9. Cosmic Vault Economy API
The `cosmicvaulteconomy.lua` library allows reading live market data and natively broadcasting economic events to the Galactic News.

### Usage
```lua
local CosmicVaultEconomy = include("cosmicvaulteconomy")
-- This will broadcast a massive market boom for Processors to the Galactic News Network
CosmicVaultEconomy.TriggerMarketEvent("Processors", 150, -50, 10, "boom")
```

## 10. Cosmic Vault Dynamic Encounters API
The `cosmicvaultencounter.lua` library helps inject custom ambushes or anomalies natively when a player enters a sector.

### Usage
```lua
local CosmicVaultEncounter = include("cosmicvaultencounter")
-- Spawns 3 aggressive Pirate ships at the player's location natively
CosmicVaultEncounter.spawnAmbush(Faction().index, 5000, 3, nil, true)
```

## 11. Cosmic Vault Mission Injector API
The `cosmicvaultmission.lua` library helps build and post standard bulletin boards natively.

### Usage
```lua
local CosmicVaultMission = include("cosmicvaultmission")
local bulletin = CosmicVaultMission.createBulletin("Bounty Target", "Kill the pirate lord", "Hard", "150,000 Cr", "data/scripts/player/missions/bounty.lua", {})
```

## 12. Cosmic Vault Progression API
The `cosmicvaultprogression.lua` library wraps native custom XP, skills, and perks natively.

### Usage
```lua
local CosmicVaultProgression = include("cosmicvaultprogression")
-- Adds 50 XP to the player's 'combat' skill tree natively
CosmicVaultProgression.addXP(playerIndex, 50, "combat")
```

## 13. Cosmic Vault Fleet Command API
The `cosmicvaultfleet.lua` library provides a safe interface to issue vanilla AI orders without rewriting craftorders.lua.

### Usage
```lua
local CosmicVaultFleet = include("cosmicvaultfleet")
-- Clear orders and make a ship jump
CosmicVaultFleet.orderJump(entityId, 15, -20)
```

## 14. Cosmic Vault Faction Traits API
The `cosmicvaultfaction.lua` library natively manages temporary faction traits.

### Usage
```lua
local CosmicVaultFaction = include("cosmicvaultfaction")
CosmicVaultFaction.setTrait(factionIndex, "aggressive", true)
```

## 15. Cosmic Vault Custom Goods API
The `cosmicvaultgoods.lua` library natively injects custom trade goods.

### Usage
```lua
local CosmicVaultGoods = include("cosmicvaultgoods")
CosmicVaultGoods.registerGood({name = "Cosmic Matter", price = 50000, volume = 5.0, icon = "data/textures/icons/cosmic.png"})
```

## 16. Cosmic Vault Custom Loot API
The `cosmicvaultloot.lua` library drops custom loot natively.

### Usage
```lua
local CosmicVaultLoot = include("cosmicvaultloot")
CosmicVaultLoot.dropCustomLoot(entityId, "good", "Cosmic Matter", 10)
```

## 17. Cosmic Vault Blueprint Spawner API
The `cosmicvaultblueprint.lua` library spawns custom ships, stations, and turrets natively.

### Usage
```lua
local CosmicVaultBlueprint = include("cosmicvaultblueprint")
local ship = CosmicVaultBlueprint.spawnShip(factionId, "data/plans/boss.xml", Matrix(), 5000)
local turret = CosmicVaultBlueprint.createTurretFromPlan("data/plans/custom_turret.xml", WeaponType.Laser)
```

## 18. Cosmic Vault Station Interaction API
The `cosmicvaultstation.lua` library adds safe UI tabs to stations.

> [!WARNING]
> Modders must define their own `initUI()` function (if needed) **before** calling `CosmicVaultStation.injectInteraction()`. Because this API safely wraps the global `initUI`, defining your own `initUI` afterwards will overwrite the Vault's hook!

### Usage
```lua
local CosmicVaultStation = include("cosmicvaultstation")
CosmicVaultStation.injectInteraction("Talk to Mercenary", "Mercenary Guild", "onMercClicked")
```

## 19. Cosmic Vault Global Events API
The `cosmicvaultevents.lua` library manages galaxy-wide timers natively.

### Usage
```lua
local CosmicVaultEvents = include("cosmicvaultevents")
CosmicVaultEvents.startEvent("xsotan_invasion", 3600) -- 1 hour event
```

## 20. Cosmic Vault Buff & Debuff API
The `cosmicvaultbuffs.lua` library applies self-terminating buffs natively, and allows tracking of global faction-wide buff tiers across sectors.

### Usage
```lua
local CosmicVaultBuffs = include("cosmicvaultbuffs")

-- Cuts ship speed in half for 30 seconds
CosmicVaultBuffs.applyBuff(entityId, "Velocity", 0.5, 30)

-- Set an empire-wide Ascension Tier buff level
CosmicVaultBuffs.setGlobalTier(factionIndex, 5)
local tier = CosmicVaultBuffs.getGlobalTier(factionIndex)
```


## Latest Additions & Integrations

- **Floating Combat Text & DoTs API**: Added `cosmicvaultcombat.lua` exposing `applyDoT` and native logic to render floating combat text for DOTs dynamically.
- **Permanent Buffs API**: Added `applyPermanentFactor` to `cosmicvaultbuffs.lua` to dynamically scale boss shields/damage directly via script natively.
