# 🌌 Cosmic Vault — Modder Guide

![Version](https://img.shields.io/badge/version-4.0.0-6f42c1?style=flat-square)
![Avorion](https://img.shields.io/badge/Avorion-2.5.13-2f81f7?style=flat-square)

Technical reference for modders building on top of Cosmic Vault's shared systems: architecture rules that will crash your mod if you ignore them, function signatures, and code examples for every public API.

> [!TIP]
> If you want prose explanations of what each system does and why, see [`WIKI.md`](WIKI.md) instead. See [`README.md`](README.md) for installation.

---

## 📑 Contents

- [🏗️ Architecture & Best Practices](#-architecture--best-practices)
- **📑 The API Library**
  - **Player, Settings & Progression** — [1. Player Settings](#-1-player-settings-api-cosmicvaultplayersettingslua) · [12. Progression](#-12-progression-api-cosmicvaultprogressionlua) · [32. Settings Schema](#-32-settings-schema-api-cosmicvaultsettingsschemalua)
  - **News & Dialogue** — [2. Galactic News](#-2-galactic-news-api-cosmicvaultnewslua) · [23. Dialogue](#-23-dialogue-api-cosmicvaultdialoguelua)
  - **Faction, Diplomacy & Conflict** — [3. Faction API & Custom Traits](#-3-faction-api--custom-traits-cosmicvaultfactionlua) · [26. Faction & Diplomacy](#-26-faction--diplomacy-api-cosmicvaultfactionlua) · [34. Conflict Scoreboard](#-34-faction-conflict-scoreboard-api-cosmicvaultconflictlua)
  - **UI & Presentation** — [4. UI Components](#-4-cosmic-ui-components-cosmicvaultuilua) · [31. UI Kit](#-31-ui-kit-api-cosmicvaultuikitlua)
  - **Scheduling, Data & Framework** — [5. Task Scheduler](#-5-task-scheduler-api-cosmicvaulttasklua) · [6. Data Serialization](#-6-data-serialization-api-cosmicvaultdatalua) · [25. Framework Core](#-25-framework-core-api-cosmicvaultframeworklua)
  - **Arsenal & Combat** — [7. Arsenal](#-7-arsenal-api-cosmicvaultarsenallua) · [20. Combat & DoTs](#-20-combat--dots-api-cosmicvaultcombatlua)
  - **Economy & Goods** — [8. Economy](#-8-economy-api-cosmicvaulteconomylua--cosmicvaultgoodslua) · [14. Goods](#-14-goods-api-cosmicvaultgoodslua) · [28. Economy Famine](#-28-economy-famine-api-cosmicvaulteconomylua)
  - **Encounters & Missions** — [9. Encounter](#-9-encounter-api-cosmicvaultencounterlua) · [10. Mission](#-10-mission-api-cosmicvaultmissionlua)
  - **Scaling & Territory** — [11. Dynamic Scaling](#-11-dynamic-scaling-api-cosmicvaultscalinglua) · [24. Territory](#-24-territory-api-cosmicvaultterritorylua)
  - **Fleet & Loot** — [13. Fleet Command](#-13-fleet-command-api-cosmicvaultfleetlua) · [15. Loot](#-15-loot-api-cosmicvaultlootlua)
  - **Blueprints & Stations** — [16. Blueprint](#-16-blueprint-api-cosmicvaultblueprintlua) · [17. Station Interaction](#-17-station-interaction-api-cosmicvaultstationlua)
  - **Events, Buffs & Weather** — [18. Global Events](#-18-global-events-api-cosmicvaulteventslua) · [19. Buffs](#-19-buffs-api-cosmicvaultbuffslua) · [30. Subspace Weather](#-30-subspace-weather-api-cv_weather_controllerlua)
  - **Config, Debug & Keybinds** — [21. Config](#-21-config-api-cosmicvaultconfiglua) · [22. Debug](#-22-debug-api-cosmicvaultdebuglua) · [27. CCM Keybinds](#-27-cosmic-configuration-menu-ccm-keybind-api-ccmlua--ccm_keycodeslua)
  - **Upgrade Categories** — [33. Upgrade Categories](#-33-upgrade-categories-api-cosmicvaultupgradecategorieslua)

---

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

> [!CAUTION]
> **Namespace Architecture & RPC Registries (VFM Hooks)**
> When replacing or appending to vanilla scripts that utilize a `-- namespace` declaration (e.g., `researchstation.lua`), you **must not** use global wrapper functions (e.g., `function initUI()`). The engine natively hooks into the namespace table and will ignore your global wrappers, silently breaking your interactions! Instead, store the old function and inject directly into the vanilla namespace table:
> ```lua
> local old_initUI = ResearchStation.initUI
> function ResearchStation.initUI(...)
>     if old_initUI then old_initUI(...) end
>     -- Your code here
> end
> ```
> Additionally, any RPC methods within a namespaced script must be registered explicitly to the namespace context using `callable(NamespaceName, "functionName")`. Using `callable(nil, ...)` will bypass the context and lead to silent multiplayer desyncs.

> [!TIP]
> **Event Loop Throttling**
> When writing background simulation scripts (e.g., `updateServer` loops), **always** define `getUpdateInterval()` to throttle execution (e.g. `return 5.0`). Running logic every single frame (0s interval) should be strictly reserved for rendering UI fading or precise physical tracking.

> [!CAUTION]
> **Rogue Globals in Library Files**
> Library files (`data/scripts/lib/*.lua`) that other scripts `include()` must not define global Avorion engine callbacks (`function updateServer(...)`, `function getUpdateInterval(...)`, etc.). When a script calls `include("yourlibrary")`, any global function defined in that library gets injected directly into the calling script's Lua VM. If the calling script also has its own `updateServer()` loop, the library's version silently overwrites it — a failure mode that's brutal to debug because nothing errors, the calling script's own loop just stops running.
> ```lua
> -- Correct library structure: return a table, never define global engine callbacks
> local MyCustomLib = {}
> function MyCustomLib.doSomething()
>     -- Logic here
> end
> return MyCustomLib
> ```

> [!WARNING]
> **Common Native API Errors**
> Be highly cautious of incorrectly used API method names when using native C++ userdata objects.
> - **Relations:** `Faction` and `Player` userdata objects do NOT have a `setRelations()` or `changeRelations()` method. You must use the global `Galaxy():setFactionRelations()` and `Galaxy():changeFactionRelations()`.
> - **Relations (Get):** Native `Galaxy():getFactionRelations(a, b)` strictly requires `Faction` objects, NOT integer indices. Wrapping indices with `Faction(index)` is mandatory.
> - **Wealth:** Factions do NOT have a `getWealth()` method. You must use the native property `faction.money`.
> - **Stats & Entities:** Use `statModifier:addBaseMultiplier()` (not `modifyBaseMultiplier`). Use `entity:addMultiplyableBias()` (not `addMultiplyableFactor`).
> - **Sectors:** `Galaxy()` does NOT have a `setFaction()` or `tryUnloadSector()` method. Sector borders are natively controlled by the stations inside them.
> - **InvokeFunction:** Routing depends on what object a script is actually attached to, not which `data/scripts/` folder it lives in. `cosmicvaultnews_server.lua` and `cosmicvaultweather_server.lua` both live under `data/scripts/server/`, but `galaxy/server.lua` attaches both with `Galaxy():addScriptOnce(...)`, so they're only reachable through `Galaxy():invokeFunction(...)` — calling `Server():invokeFunction()` on either one fails. Check where a script is actually attached (`addScript`/`addScriptOnce`) before assuming its folder tells you the right object to call.
> - **Client Functions:** When communicating from a server script to a player script, use the global `invokeClientFunction(Player(), "functionName", args...)` to safely cross the server-client boundary.
> - **Blueprints:** `BlockPlan` does NOT have `plan:fromString()`. Use the global `LoadPlanFromString()`.
> - **Loot Drops:** Use `Sector():dropTurret()` for weapons and `Sector():dropUpgrade()` specifically for SystemUpgradeTemplate objects. Mismatching these will crash the sector.
> Stormbox: This is from my personal findings and debugging often.

> [!NOTE]
> **Cosmic Vault Runs Standalone**
> Every `include()` inside Cosmic Vault that reaches into a sister mod's files — the Cosmic War economy bridge, the three sister config menus (Overhaul/War/Ascendancy), and Chronicles' Famine Relief Cache spawn — is wrapped in `pcall` as of v3.5.0. A Vault-only install, or Vault plus a subset of the Core 4, simply skips those cross-mod hooks instead of crashing. If you build a similar cross-mod hook in your own mod, follow the same pattern: `pcall(include, "someOtherModsLib")` rather than a bare `include()`.
---

## 📑 The API Library

### ⚙️ 1. Player Settings API (`cosmicvaultplayersettings.lua`)
A fail-safe wrapper around Avorion's `Player():setValue()` system, replacing direct `.json` file I/O, which is prone to server locks.
```lua
local PlayerSettings = include("cosmicvaultplayersettings")
PlayerSettings.set(Player(), "MyMod", "FeatureEnabled", true)
local isEnabled = PlayerSettings.get(Player(), "MyMod", "FeatureEnabled", true)
```

### 📰 2. Galactic News API (`cosmicvaultnews.lua`)
Publish versioned facts into the server-owned feed. Stable event IDs make retries idempotent, while revision checks prevent one publisher from overwriting another publisher's story or applying a stale update.
```lua
local CosmicVaultNews = include("cosmicvaultnews")
if onServer() then
    CosmicVaultNews.RegisterPublisher({
        schemaVersion = 1,
        publisherId = "my_mod",
        displayName = "My Mod",
        shortName = "MY",
        color = {r = 0.4, g = 0.8, b = 1.0},
    })

    local article, err, created = CosmicVaultNews.Publish({
        schemaVersion = 2,
        publisherId = "my_mod",
        eventId = "invasion:-12:8:42",
        threadId = "war:12:19",
        eventType = "my_mod.invasion.started",
        topic = "conflict",
        category = "War Update",
        severity = "critical",
        breaking = true,
        title = "Invasion Confirmed",
        content = "A verified invasion has begun in sector [-12:8].",
        location = {x = -12, y = 8, radius = 0},
        audience = {mode = "galaxy"},
        provenance = {recordType = "my_event_v1", recordId = "42", sourceRevision = 3},
    })
end
```
Use `Update(articleId, publisherId, expectedRevision, patch)` for a developing report and `Resolve(articleId, publisherId, expectedRevision, resolution)` for its outcome. Keep `publisherId`, `eventId`, and `threadId` stable. The manager rejects non-serializable values, so convert engine objects such as `Entity`, `Faction`, `Uuid`, `Color`, and `NamedFormat` into strings or numbers before publishing.

Queries are server-only and cursor-based:
```lua
if onServer() then
    local page, err = CosmicVaultNews.Query({
        pageSize = 30,
        beforeSequence = nil,
        topics = {conflict = true},
        states = {active = true},
        audiencePlayerIndex = Player().index,
    })
end
```
`page.items`, `page.nextCursor`, `page.hasMore`, `page.feedRevision`, and `page.latestSequence` are defensive snapshots. `onCosmicVaultNewsChanged(feedRevision, articleId, changeType)` only announces that data changed; query after the callback returns.

The lowercase `publishArticle(article)` and `getPublishedNews()` wrappers remain for old publishers. They use the v2 store but cannot provide a strong developing-story identity unless the caller supplies the v2 fields.

### 🗃️ 3. Faction API & Custom Traits (`cosmicvaultfaction.lua`)
A cached list of generated factions, plus an API for injecting custom faction traits into the vanilla diplomacy window without touching Avorion's hardcoded UI.

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

**Generic Per-Actor Resource Ledger (v4.0.0):** a "banked resource against a specific faction" primitive — Intel, favor, reputation, anything shaped like it. `actor` is anything supporting `getValue`/`setValue`: a `Player()` for a per-player ledger, or an `Alliance()` to pool it across an Alliance's members. `ledgerKey` namespaces the resource so multiple mods/mechanics can safely share one actor.
```lua
cvf.grantLedger(player, targetFactionIndex, "intel", 25)      -- server-only
local balance = cvf.getLedger(player, targetFactionIndex, "intel")
local spent = cvf.spendLedger(player, targetFactionIndex, "intel", 50)  -- false if insufficient balance
```

### 🖥️ 4. Cosmic UI Components (`cosmicvaultui.lua`)
Triggers cinematic screen overlays and banners, and provides flexible UI partitions, without writing a custom renderer.
```lua
local CosmicVaultUI = include("cosmicvaultui")
CosmicVaultUI.ShowCinematicBanner(Player(), "CRITICAL WARNING", ColorRGB(1, 0, 0), "data/sounds/siren.ogg", 5)
```

### ⏳ 5. Task Scheduler API (`cosmicvaulttask.lua`)
Runs intensive Lua operations across multiple server ticks using coroutines, instead of stalling one frame and dropping server TPS.
```lua
local CosmicVaultTask = include("cosmicvaulttask")
CosmicVaultTask.RunAsync("MyHeavyScan", function()
    for i=1, 10000 do
        CosmicVaultTask.Yield() -- Pauses execution until the next Update tick
    end
end)
```

### 💾 6. Data Serialization API (`cosmicvaultdata.lua`)
Stores complex Lua tables on entities and applies tags for fast grouping and querying, using `dkjson`.
```lua
local CosmicVaultData = include("cosmicvaultdata")
CosmicVaultData.SetTable(entity, "MyCustomData", {isBoss = true})
CosmicVaultData.AddTag(entity, "VIP_Target")
```

For durable state-machine records, use the versioned record API. It JSON-encodes the table because
Avorion custom values accept scalar values, not Lua tables:

```lua
local saved, err = CosmicVaultData.SetRecord(Server(), "my_record_v1", {
    schemaVersion = 1,
    revision = 0,
    state = "pending"
})

local record, readError = CosmicVaultData.GetRecord(Server(), "my_record_v1", 1)
```

`SetRecord(actor, key, record)` requires a numeric `schemaVersion`, rejects cyclic/functions/userdata,
and supports any verified Server, Player, Alliance, Faction, or Entity actor with `getValue`/`setValue`.
`GetRecord(actor, key, expectedVersion)` distinguishes `missing`, `corrupt`, and
`unsupported_version`. Existing `SetTable` and `GetTable` behavior is unchanged.

### ⚔️ 7. Arsenal API (`cosmicvaultarsenal.lua`)
Generates properly balanced, custom `Weapon`/`InventoryTurret` objects dynamically.
```lua
local CosmicVaultArsenal = include("cosmicvaultarsenal")
local turret = CosmicVaultArsenal.GenerateTurret({rarity = Rarity(RarityType.Legendary), weaponType = WeaponType.Bolter, damage = 500})
```
As of v3.5.0, `rarity` and `material` are written to the generated `Weapon` object and actually take effect — earlier versions wrote them to `InventoryTurret` instead, which silently discards both since they're read-only there. **`weaponType` still does nothing.** It isn't wired to anything the engine reads; giving a weapon a real per-type identity (Bolter vs. Laser vs. Cannon, etc.) needs the manual physics setup vanilla's own `weapongenerator.lua` does — `Weapon:setProjectile()`/`:setBeam()`, `fireDelay`, `pvelocity`, and related fields — which this helper doesn't implement. Pass it if you like for readability, but don't expect it to change the result.

When the weapon type must be genuine, use `GenerateTypedTurret(config)`. This validates the type
against vanilla `turretgenerator.lua` and delegates to its seeded typed dispatcher:

```lua
local turret, err = CosmicVaultArsenal.GenerateTypedTurret({
    seed = Seed(12345), weaponType = WeaponType.Laser,
    dps = 250000, tech = 52,
    rarity = Rarity(RarityType.Legendary),
    material = Material(MaterialType.Avorion), coaxialAllowed = true
})
```

Unsupported weapon types and invalid configuration return `nil, error`. `GenerateTurret` remains
available with its original behavior.

### 💹 8. Economy API (`cosmicvaulteconomy.lua` & `cosmicvaultgoods.lua`)
Reads live market data, broadcasts economic events, and injects custom trade goods into the five global vanilla economy arrays.
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

`TriggerMarketEvent` remains compatible and now starts a persistent event. New code can control the
full lifecycle directly:

```lua
local event, err = CosmicVaultEconomy.StartMarketEvent({
    sourceId = "my_factory", goodName = "Processors",
    x = 150, y = -50, radius = 10, eventType = "boom",
    duration = 1800, notify = false
})
local current = CosmicVaultEconomy.GetMarketEvent(event.eventId)
local delta = CosmicVaultEconomy.GetMarketPriceDelta("Processors", 151, -50,
    Server().unpausedRuntime)
CosmicVaultEconomy.EndMarketEvent(event.eventId, "source_removed")
```

Boom and crash default to `+0.10` and `-0.10`. The default duration is 30 minutes. A repeated event
from the same source and scope refreshes instead of stacking; distinct overlapping events combine,
with the final price delta clamped to vanilla's `-0.30` to `+0.30` range. `notify = false` suppresses
only the broadcast.

### 🏴‍☠️ 9. Encounter API (`cosmicvaultencounter.lua`)
Injects custom ambushes or anomalies when a player enters a sector.
```lua
local CosmicVaultEncounter = include("cosmicvaultencounter")
CosmicVaultEncounter.spawnAmbush(Faction().index, 5000, 3, nil, true)
CosmicVaultEncounter.broadcastEncounterMessage("Pirate Lord", "You picked the wrong sector!", true)
```

### 📜 10. Mission API (`cosmicvaultmission.lua`)
Builds and posts standard bulletin-board missions.
```lua
local CosmicVaultMission = include("cosmicvaultmission")
local bulletin = CosmicVaultMission.createBulletin("Bounty Target", "Kill the pirate lord", "Hard", "150,000 Cr", "script.lua", {})

-- Fails the mission and handles UI notifications
CosmicVaultMission.failMission(missionId)

-- Grants physical item templates to the player upon success
CosmicVaultMission.grantItemReward(itemTemplate, amount)
```

**Extended bulletin builder (v4.0.0):** a superset of `createBulletin()` for when you need `formatArguments` (dynamic reward-text substitution) or `onAccept` (an inline accept-time script) — the original's fixed parameter list doesn't support either. Fully additive; `createBulletin()` is unchanged.
```lua
local bulletin = CosmicVaultMission.createBulletinEx({
    title = "Bounty Target", description = "Kill the pirate lord", difficulty = "Hard",
    rewardText = "¢${reward}", scriptPath = "script.lua",
    args = { { reward = rewardStruct } },
    formatArguments = { reward = createMonetaryString(rewardCredits) },
    onAccept = [[
        local self, player = ...
        player:sendChatMessage("Bounty Board", 0, "Good hunting."%_T)
    ]]
})
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
`getXP()` and `hasPerk()` are server-only and guard against being called on the client as of v3.5.0 — earlier versions crashed with `invalid userobject of type Player` if a client-side script (a HUD widget, say) called either one directly. The same fix applies to `cosmicvaultplayersettings.lua`'s `get`/`set` (section 1).

### 🎖️ 13. Fleet Command API (`cosmicvaultfleet.lua`)
Safe interface to issue vanilla AI orders without rewriting `craftorders.lua`.
```lua
local CosmicVaultFleet = include("cosmicvaultfleet")
CosmicVaultFleet.orderJump(entityId, 15, -20)

-- Automates mining and salvaging behaviors for AI ships safely
CosmicVaultFleet.orderMine(entityId, clearPrevious)
CosmicVaultFleet.orderSalvage(entityId, clearPrevious)

-- Orders a ship to escort another entity
CosmicVaultFleet.orderEscort(entityId, targetId, clearPrevious)
```
`orderEscort` only actually tracks a target as of v3.5.0. Earlier versions passed a plain string where the underlying `OrderChain.addEscortOrder` expects a raw `Uuid`, so the order was accepted but the ship never had anything to escort.

### 🧬 14. Goods API (`cosmicvaultgoods.lua`)
Registers custom trade goods.
```lua
local CosmicVaultGoods = include("cosmicvaultgoods")
CosmicVaultGoods.registerGood({name = "Cosmic Matter", price = 50000, size = 5.0})
```

### 💎 15. Loot API (`cosmicvaultloot.lua`)
Drops custom loot.
```lua
local CosmicVaultLoot = include("cosmicvaultloot")
CosmicVaultLoot.dropCustomLoot(entityId, "good", "Cosmic Matter", 10)

-- Specifically spawns upgrade templates as physical drops in space
CosmicVaultLoot.SpawnLootUpgrade(Sector(), x, y, z, "data/scripts/systems/bossupgrade.lua", Rarity(RarityType.Legendary))
```
As of v3.5.0, `dropCustomLoot` passes the reservation slots as real `Faction` objects and the correct argument order for the `"good"` branch. Before that fix, every custom good drop requested zero units regardless of the `amount` argument — if you called this in an earlier version and it looked like it silently did nothing, that's why.

### 🏗️ 16. Blueprint API (`cosmicvaultblueprint.lua`)
Spawns custom ships and stations from XML plans.
```lua
local CosmicVaultBlueprint = include("cosmicvaultblueprint")
local ship = CosmicVaultBlueprint.spawnShip(factionId, "data/plans/boss.xml", Matrix(), 5000)
```
The `volume` argument (`5000` above) scales the loaded plan to that volume. **This only works as of v3.5.0.** Earlier versions called `plan:scale(aNumber)` with a plain number, but `BlockPlan:scale()` takes a `vec3`, so every call that passed `volume` — including this exact example — crashed immediately. If you're on an older Vault version, omit the argument or update.

`createTurretFromPlan(xmlPlan, weaponType, rarity, material)` **is not implemented and never has been.** `InventoryTurret.rarity`/`.material`/`.weaponPrefix` are all read-only, and there's no `customTurretDesign` field or any other documented way to attach a block Plan as a turret's visual model anywhere in the engine. Calling it logs an error and returns `nil` — it won't silently hand you a broken turret, but it also won't build one from your plan. Use `CosmicVaultArsenal.GenerateTurret()` for programmatic turret generation instead.

### 🛰️ 17. Station Interaction API (`cosmicvaultstation.lua`)
Adds safe UI tabs to stations.
> [!TIP]
> Define your `initUI()` function **before** calling `CosmicVaultStation.injectInteraction()`.
```lua
local CosmicVaultStation = include("cosmicvaultstation")
CosmicVaultStation.injectInteraction("Talk to Mercenary", "Mercenary Guild", "onMercClicked")

-- Safely check interaction ranges (now supports custom maxDistance overrides)
if CosmicVaultStation.isInteractionPossible(500) then ... end
```

### ⏰ 18. Global Events API (`cosmicvaultevents.lua`)
Manages galaxy-wide timers that persist across server reboots.
```lua
local CosmicVaultEvents = include("cosmicvaultevents")
CosmicVaultEvents.startEvent("xsotan_invasion", 3600)
```

### 🚀 19. Buffs API (`cosmicvaultbuffs.lua`)
Applies self-terminating buffs, tracks global faction-wide buff tiers, and calculates dynamic "Living Relic" modifiers. Supported buff mappings: `Velocity`, `Shield`, `Damage`, `Acceleration`, `HyperspaceCooldown`.
```lua
local CosmicVaultBuffs = include("cosmicvaultbuffs")
-- Apply a 30 second -50% speed debuff
CosmicVaultBuffs.applyBuff(entityId, "Velocity", 0.5, 30)

-- Fetch the dynamic multiplier for Living Relics (e.g. 1.0 - 2.5 multiplier based on Core Distance and War Heat)
local finalMultiplier = CosmicVaultBuffs.getDynamicRelicMultiplier(entity.id)

-- Permanently multiply base stats, safely utilizing C++ callbacks without infinitely stacking
CosmicVaultBuffs.addPermanentBaseMultiplier(entityId, "Damage", 0.15)

-- Removing a permanent factor/multiplier only actually works as of v3.5.0
CosmicVaultBuffs.removePermanentBaseMultiplier(entityId, "Damage")
```
Before v3.5.0, `removePermanentFactor`/`removePermanentBaseMultiplier` called engine methods that don't exist, and the `apply`/`add` functions threw away the bonus key needed to remove anything even after that was fixed. Permanent buffs could be applied but never removed, and reapplying one stacked indefinitely. Removal is now tracked per entity/stat and is safe to call repeatedly.

**As of v3.6.0:** if you call `applyBuff` with a `buffId` on the standard `refreshBuff` fails → `applyBuff` pattern (see Cosmic Overhaul's `captainelitetraits.lua` for the reference implementation), be aware it now enforces a 15-second cooldown per `(entity, buffId)` — a second `applyBuff` call for the same id within that window is silently ignored rather than attempting another attach. This exists to stop a poll loop from retrying an attach every cycle if it's failing for reasons outside this API's control; it does not affect id-less calls (no retry loop is possible without an id to refresh against) and is cleared immediately by a successful `refreshBuff` or an explicit `terminateBuff`.

### 🔥 20. Combat & DoTs API (`cosmicvaultcombat.lua`)
Renders floating combat text and applies Damage-over-Time effects.
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
Provides trace logging, error catching, and performance metrics.
```lua
local CosmicVaultDebug = include("cosmicvaultdebug")
CosmicVaultDebug.log("System initialized successfully in 12ms.")
```

### 💬 23. Dialogue API (`cosmicvaultdialogue.lua`)
The v2 catalog is owned by one server manager, so entries registered in a galaxy script remain visible to player, sector, and entity scripts running in other Lua VMs.
```lua
local CosmicVaultDialogue = include("cosmicvaultdialogue")
CosmicVaultDialogue.RegisterPublisher({
    schemaVersion = 1,
    publisherId = "my_mod",
    displayName = "My Mod",
    shortName = "MY",
    color = {r = 0.4, g = 0.8, b = 1.0},
})

CosmicVaultDialogue.RegisterEntries("my_mod", {{
    schemaVersion = 2,
    lineId = "my_mod:rumor:blockade-01",
    category = "rumor",
    text = "Freighters are avoiding the eastern gate.",
    weight = 1,
    tags = {"station", "conflict"},
    conditions = {
        minWarHeat = 40,
        stationTypes = {tradingpost = true},
        topics = {conflict = true},
    },
}})

local result, err = CosmicVaultDialogue.Query("rumor", {
    warHeat = 72,
    stationType = "tradingpost",
    topics = {conflict = true},
}, {
    seed = 12345,
    excludeIds = {"my_mod:rumor:older-line"},
})
```
Supported numeric ranges cover War Heat, reputation, and distance to center. Set predicates cover station types, faction traits/wealth, publisher IDs, topics, severities, weather types, Eclipse states, and captain classes; `riftActive` is boolean. Unknown predicates, functions, userdata, and metatables are rejected.

The lowercase `registerLine` and `getValidLine` functions remain compatible. New code should keep stable line IDs and save the returned ID when it needs per-player repetition suppression.

### 🗺️ 24. Territory API (`cosmicvaultterritory.lua`)
Manages mathematical territory expansion and station flips without triggering the "Sector Alive" performance trap (loading a sector just to flip a station's owner). Includes bindings to `CosmicVaultNews` and functions for background faction generation.

> [!NOTE]
> **Progressive Materialization:** Due to engine limits in Avorion 2.0+, stations in unloaded sectors cannot be physically changed without loading and simulating the sector. The Territory API stores versioned JSON queue records and lets the shared player-entry consumer perform the work when the sector is already loading. Legacy pending strings are imported once and preserved only as migration evidence.

> [!TIP]
> **Precise Siege Progress:** The `setContestedZone()` API automatically injects an absolute `startTime` property (using `Server().unpausedRuntime`) into the serialized background simulation state. Client-side scripts like `cw_battlefieldhud.lua` can pass `zone.startTime` from the server down to the client to render 100% mathematically accurate siege progress bars even for players who join hours late.

```lua
local CosmicVaultTerritory = include("cosmicvaultterritory")

-- Set a sector to be conquered by faction 2 from faction 3 after 60 minutes.
CosmicVaultTerritory.setContestedZone(x, y, 2, 3, 60)

-- Dynamically generate a new outpost or pirate base in empty space without crashing the server.
CosmicVaultTerritory.expandToSector(x, y, factionIndex, isPirate)

-- New durable queue workflow. Coordinates, including negatives, are exact identities.
local queued = CosmicVaultTerritory.QueueMaterialization("my_kind", x, y, {
    factionIndex = factionIndex
})
local claimed = CosmicVaultTerritory.ClaimMaterialization("my_kind", x, y,
    "my-worker", 60)
-- Perform the external work, verify its entity/script/result, then:
CosmicVaultTerritory.CompleteMaterialization("my_kind", x, y, "my-worker", {
    entityId = station.id.string
})
-- Or retain it with bounded backoff:
CosmicVaultTerritory.RetryMaterialization("my_kind", x, y, "my-worker",
    "station_creation_failed", 300)
-- If the worker persisted an external side effect but cannot prove whether it completed,
-- stop automatic retries and expose the operation to the repair tooling instead.
CosmicVaultTerritory.RequireMaterializationRepair("my_kind", x, y, "my-worker",
    "external_receipt_ambiguous")

-- Find where faction 2's and faction 3's territory actually meet, within 15 sectors of the
-- midpoint between their home sectors -- e.g. to highlight a contested frontline on the map.
local border = CosmicVaultTerritory.getBorderSectors(2, 3, 15)
for _, sector in pairs(border) do
    -- sector.x, sector.y
end
```

`GetMaterialization(kind, x, y)` returns the current record. Identical queue requests coalesce;
conflicting payloads for the same kind/coordinate return an error and mark the record for repair.
Claims expire back to `retryable`, work is never removed before verified completion, automatic
attempts stop at five, and completed tombstones are retained for seven days. `resolveSiege` and
`expandToSector` remain public compatibility wrappers and enqueue through this lifecycle.
`RequireMaterializationRepair` is for the unsafe crash window after an external system may already
have applied its side effect; it deliberately prevents an automatic retry from duplicating that
effect. `ResolveMaterializationRepair` is the administrator-side resolution hook.

### 🧩 25. Framework Core API (`cosmicvaultframework.lua`)
The internal state machine and bootstrapper for all vault APIs. Generally not interacted with directly, but handles dependency injection and strict type-checking.
```lua
local CosmicVaultFramework = include("cosmicvaultframework")
-- Aggressive development type-checking to prevent silent UI or server failures
CosmicVaultFramework.assertType(playerIndex, "number", "playerIndex")
```

### 🤝 26. Faction & Diplomacy API (`cosmicvaultfaction.lua`)
Manages faction properties and diplomacy, including mirroring reputation gains to player alliances without causing crashes or double-penalties. Also provides a custom trait registry ("Aggressive", "Industrial", etc.) for other mods to tag vanilla factions.
```lua
local CosmicVaultFaction = include("cosmicvaultfaction")

-- Safely applies -5000 relations to player/faction and cleanly mirrors it to their alliance if applicable
CosmicVaultFaction.changeRelations(player.index, targetFaction.index, -5000)

-- Register and assign a custom trait for cross-mod synergy
CosmicVaultFaction.registerCustomTrait("industrial", "Industrial", {"Produces more goods"})
CosmicVaultFaction.setTrait(factionIndex, "industrial", true)
if CosmicVaultFaction.getTrait(factionIndex, "industrial") then
    -- Do something specific for industrial factions
end
```
Custom traits registered this way only actually render in the diplomacy window as of v3.5.0. Every version before that hooked `Diplomacy.updateFactionInformation`, a function name that has never existed anywhere in vanilla `diplomacy.lua` — the real trait-rendering function is `Diplomacy:updateTraits(faction)`. Traits were computed correctly the whole time; they just never drew.


---

### 🎮 27. Cosmic Configuration Menu (CCM) Keybind API (`ccm.lua` & `ccm_keycodes.lua`)
A user-configurable keybind framework integrated into the CCM UI.
```lua
local ccm = include("ccm")
local cvcfg = ccm.bind("CosmicVault")
if cvcfg.isKeyComboDown("hotkeyCodex") then
    -- Execute action when ALT+P (default) is pressed
end
```
Register keybinds dynamically by using `type = "keybind"` in your `ccm.register` options array. The API filters out inputs while players are typing in chat, and supports unbinding via the `Delete` and `Backspace` keys.

### 🌾 28. Economy Famine API (`cosmicvaulteconomy.lua`)
Exposes `addFamineScore` and `getFamineLevel` to track faction starvation, creating dynamic resource shortages and inflation across an entire empire's territory.
```lua
local CosmicVaultEconomy = include("cosmicvaulteconomy")
CosmicVaultEconomy.addFamineScore(factionIndex, 500)
local severity = CosmicVaultEconomy.getFamineLevel(factionIndex)
```

**Relief-applied tracker (v4.0.0):** a running, never-reset total for any score family, not just Famine — generalizes a pattern Cosmic War built for its own Warbonds system (a payout scaling off how a tracked score changed during a holding period, which a player could otherwise game by personally applying the relief action that would guarantee a good outcome). Snapshot the total at the start of a hold, diff it at the end, and back that delta out of your own raw-score comparison.
```lua
CosmicVaultEconomy.recordReliefApplied("famine", factionIndex, 20)   -- server-only
local totalEverApplied = CosmicVaultEconomy.getReliefApplied("famine", factionIndex)
```

**Passive decay registry (v4.0.0):** register a score family that should drift toward a floor over time; Cosmic Vault has no background loop of its own, so call `tickPassiveDecay` from your own mod's existing update cycle.
```lua
CosmicVaultEconomy.registerPassiveDecay("my_corruption_", 5, 0) -- 5/hour toward 0
-- inside your own mod's background update(timeStep):
CosmicVaultEconomy.tickPassiveDecay("my_corruption_", factionIndex, timeStep)
```

**Galactic Hostility Index (v4.0.0):** a soft read of the sum of every AI faction's current War Heat, published by Cosmic War if installed. Returns 0 if Cosmic War isn't installed or hasn't published one yet — no hard dependency required.
```lua
local hostility = CosmicVaultEconomy.getGalacticHostilityIndex()
```

### 🛠️ 29. Anomalies API (`cosmicvaultanomalies.lua`)
Exposes logic for generating permanent, interactive points of interest.
```lua
local CosmicVaultAnomalies = include("cosmicvaultanomalies")
CosmicVaultAnomalies.spawnAnomaly(x, y, "SpatialRift")
CosmicVaultAnomalies.spawnAnomaly(x, y, "PrecursorWreck")
```
Both anomaly types have called `entity:addScriptOnce()` against `data/scripts/entity/cv_anomaly_rift.lua` and `cv_anomaly_wreck.lua` since this API launched in v3.0.0 — but neither file existed until v3.5.0. Anything spawned before that update sat in the sector with no interaction and no behavior attached. Both are now implemented: each offers a one-time Salvage/Channel interaction that drops a scaled reward, then leaves the entity behind as a permanent landmark.

### 🛠️ 30. Environmental Weather and Rift APIs (`cosmicvaultweather.lua`, `cosmicvaultrift.lua`)

Cosmic Vault owns a versioned galaxy record for localized environmental conditions. Callers submit
server-side intent; the Vault attaches and reconciles the loaded-sector controller, applies built-in
mechanics, and sends each player a coordinate-scoped UI snapshot. Do not attach
`cv_weather_controller.lua`, `cv_weather_debuff.lua`, or `cv_weather_ui.lua` directly. Those files
exist only to migrate old attachments.

```lua
local Weather = include("cosmicvaultweather")

local condition, err = Weather.StartWeather({
    sourceId = "my-mod:storm:12:-8",
    weatherType = "IonStorm",
    x = 12,
    y = -8,
    duration = 1800,             -- seconds; use -1 for no automatic expiry
    conflictPolicy = "reject"    -- or "replace"
})

if condition then
    Weather.RefreshWeather(condition.conditionId, 1800)
    local current = Weather.GetWeather(condition.conditionId)
    local atCoordinate = Weather.ListWeatherAt(12, -8)
    Weather.EndWeather(condition.conditionId, "source_removed")
end
```

The public lifecycle is:

- `StartWeather(options)` — creates a deterministic condition or refreshes an identical source.
- `RefreshWeather(conditionId, duration)` — updates the expiry without changing ownership.
- `EndWeather(conditionId, reason)` — ends only that condition and leaves a bounded tombstone.
- `GetWeather(conditionId)` — returns the active record or retained tombstone.
- `ListWeatherAt(x, y)` — returns every active condition at an exact coordinate.
- `GetWeatherSnapshot()` — returns the bounded galaxy record for diagnostics.

All calls return `result, nil` on success or `nil, errorCode`. They are server-only. Expected errors
include `client_context`, `invalid_arguments`, `unknown_type`, `type_conflict`,
`stacking_conflict`, `corrupt`, `unsupported_version`, and `persistence_failure`.

The built-ins are `IonStorm`, `SolarFlare`, `DarkMatterFog`, and `RiftInstability`. Atmospheric
weather uses the exclusive `atmosphere` stacking group. Rift instability uses the independent
`rift` group, so one atmospheric condition and one Rift condition can coexist at the same
coordinate. A different source in the same group is rejected unless the caller explicitly selects
`conflictPolicy = "replace"`. The environment UI uses native sector problems, entry warnings, and
client-only particles and thunder. It never changes persistent sector fog.

External mods can register presentation-only types:

```lua
local definition, err = Weather.RegisterWeatherType({
    type = "StaticField",
    category = "weather",
    stackingGroup = "static",
    icon = "data/textures/icons/hazard-sign.png",
    color = {r = 0.2, g = 0.7, b = 1.0},
    name = "Static Field",
    detailedName = "Charged Static Field",
    description = "Local space is electrically unstable.",
    chatWarning = "WARNING: Static field detected.",
    presentationProfile = "ion",
    mechanicsProfile = "presentation_only"
})
```

Custom definitions must contain plain serializable data. Vault does not execute function callbacks
stored by another script VM, and external types cannot select a built-in mechanics profile. A custom
presentation profile that Vault does not recognize still receives its sector-problem icon and text
but no built-in particle pattern. Registering different data under an existing type returns
`type_conflict` and stores a bounded `repair_required` finding in `GetWeatherSnapshot()`; Vault never
changes the live definition silently.

The old `triggerStorm`, `clearStorm`, and `getWeatherAt` calls remain compatible. Legacy secure
weather maps migrate once into `cv_weather_v2`; their original secure evidence is retained. A loaded
legacy controller submits its remaining duration to the manager and then retires.

Rift presentation uses the same condition lifecycle without requiring the DLC:

```lua
local Rift = include("cosmicvaultrift")
local condition, err = Rift.StartRiftHazard({
    sourceId = "my-mod:rift:12:-8",
    x = 12, y = -8, duration = -1,
    conflictPolicy = "reject"
})
Rift.EndRiftHazard(condition.conditionId, "rift_closed")
```

`ReportGuardianDestroyed(eventId, evidence)` and `ReportDeepExtraction(eventId, evidence)` feed the
separate `cv_rift_escalation_v1` record. Guardian event IDs use `guardian:<entity UUID>`. Deep
extractions at depth 50 or greater use a player/sector/depth fingerprint. Events are receipted and
deduplicated. Escalation is `guardianKills + deepExtractions * 0.5`; each point above 10 adds a 5%
swarm-dispatch chance, capped at 50%. The manager prepares, attaches, and verifies attacks before it
reduces the counters. Failed attachments retry five times. An interrupted materialization becomes
`repair_required` rather than repeating an uncertain attack.

The Guardian tracker is now additive and loaded only for already-loaded Rift sectors when Into the
Rift is installed. Vault no longer replaces vanilla `riftguardian.lua`. Deep extraction still needs
a small extension at `data/scripts/dlc/rift/lib/riftmissionutility.lua` because the DLC exposes no
public extraction-success callback; that path remains a documented VFS collision surface.

Spatial Rift anomaly claims use the entity-local `cv_anomaly_rift_claim_v1` record. The reward
snapshot is stored before any loot drop. A restored `claim_prepared`, corrupt record, or unsupported
schema becomes visibly `repair_required` and never replays loot automatically.

### 🧰 31. UI Kit API (`cosmicvaultuikit.lua`)
Shared player-window tab building blocks in the visual style Cosmic Overhaul's Command Center and Factory Overview tabs already established: a two-row header layout, a sortable ListBoxEx-backed table, and a canonical status-color palette. Client-only.

```lua
local UIKit = include("cosmicvaultuikit")

-- Two-row header (title/totals row, then a controls row), with room reserved for a
-- sortable column-button strip at the bottom -- the exact arithmetic three different
-- Cosmic Overhaul files got wrong independently before this existed.
local layout = UIKit.createHeaderLayout(tab, { rows = { {fraction = 0.4}, {fraction = 0.4} } })
tab:createLabel(layout.rows[1], "My Tab"%_t, 20)

-- Sortable table. IMPORTANT: pass your OWN namespace table first (MyMod below) -- the
-- engine resolves button/list callbacks against the calling script's own namespace,
-- never against cosmicvaultuikit's, so this call installs its dispatcher functions
-- directly onto the table you pass in.
local table_ = UIKit.createSortableTable(MyMod, tab, layout.contentRect, {
    { label = "Name"%_t, width = 2, sortValue = function(r) return r.name end, cellText = function(r) return r.name end },
    { label = "Status"%_t, width = 1, sortValue = function(r) return r.pct end,
      cellText = function(r) return r.pct.."%" end,
      cellColor = function(r) return UIKit.statusColorForPercent(r.pct) end },
}, { sortStripRect = layout.sortStripRect })

table_:setRows(myRowData)
table_:setSelectionChangedHandler(function(row) -- row is the original data table for the clicked row
    -- ...
end)
```

**Faction dossier tooltip (v4.0.0):** formats a consistent "=== Name ===\nTraits: ...\nRelation: ..." block from already-resolved plain data. Client-only, additive alongside any tab's existing tooltip formatting — not a required migration.
```lua
local tooltip = UIKit.buildFactionTooltip({
    name = faction.name,
    traits = "Aggressive, Mercantile",
    relationText = "Friendly (12000)",
    extraLines = { "Famine Score: 60", "Your Intel: 50 (spend 50 via /cosmicwarintel)" }
})
```

**Dossier panel (v4.0.0):** a labeled key/value detail panel — the companion to a sortable table (above): select a row, show its full detail alongside. Rows are a fixed pool toggled by `setData()`, not recreated per refresh — same reasoning as the sortable table's own row reuse. Client-only.
```lua
-- Build once, alongside your table:
local dossier = UIKit.createDossierPanel(tab, dossierRect, { maxRows = 10 })

-- Then refresh it whenever the selected row changes:
dossier:setData({
    title = faction.name,
    rows = {
        { label = "Trait"%_t, value = "Warmonger"%_t, tooltip = "Highly aggressive and eager to declare war."%_t }, -- tooltip is optional, set on both the label and value/bar cells
        { label = "War Heat"%_t, bar = heat, color = UIKit.statusColorForPercent(heat * 100, { invert = true }) },
        { label = "Famine"%_t, value = "Critical"%_t, color = UIKit.STATUS_COLORS.red },
    }
})
```

### 🗂️ 32. Settings Schema API (`cosmicvaultsettingsschema.lua`)
A schema-driven convenience layer over `cosmicvaultplayersettings.lua`: define a mod's settings once (`key`, `default`, `type`) and get validated get/set/reset instead of hand-plumbing each setting through 2-3 places.

```lua
local Schema = include("cosmicvaultsettingsschema")
local mySettings = Schema.define("MyMod_HUD", {
    { key = "Enabled", default = true, type = "bool" },
    { key = "Opacity", default = 0.0, type = "number" },
})

-- Server-side (an RPC handler, a background script):
mySettings:set(player, "Enabled", false)
local all = mySettings:getAll(player)

-- Client-side (a HUD render loop reading its own local player's settings):
local enabled = mySettings:getLocal("Enabled")
```

> [!WARNING]
> `get`/`set`/`getAll`/`resetToDefaults` are server-only, same restriction as the `cosmicvaultplayersettings.lua` they're built on. `getLocal` is the client-side path, and it deliberately does NOT go through `cosmicvaultplayersettings.lua` at all — see the doc comment at the top of `cosmicvaultsettingsschema.lua` for a real, still-unresolved discrepancy between that file's stated client-crash restriction (WIKI.md section 10) and Cosmic Overhaul's own shipped `resourcedisplay.lua`, which has safely called the equivalent bare `Player():getValue()` client-side across multiple releases. Read that note before assuming either side of this module is bulletproof.

### 🗂️ 33. Upgrade Categories API (`cosmicvaultupgradecategories.lua`)
Shared registry sorting an upgrade system script into Military/Civilian/Misc, so a category-based shop UI (Cosmic Overhaul's split Equipment Dock tabs, for one) doesn't need its own hand-maintained lookup table. Server and client safe — plain data, no engine calls.

```lua
local UpgradeCategories = include("cosmicvaultupgradecategories")

-- Register your own mod's upgrade systems once, wherever they're defined:
UpgradeCategories.registerCategory("data/scripts/systems/myShieldSystem.lua", UpgradeCategories.Category.Military)

-- A shop UI reads categories back to sort its stock:
local category = UpgradeCategories.getCategory("data/scripts/systems/myShieldSystem.lua")
local militaryScripts = UpgradeCategories.getScriptsOfCategory(UpgradeCategories.Category.Military)
```

> [!NOTE]
> All 25 vanilla-generatable upgrade systems are pre-registered — cross-referenced against the actual `scripts` table in vanilla's own `data/scripts/lib/upgradegenerator.lua`, not the `systems/` folder listing (which also holds quest-locked and Behemoth-exclusive items a normal shop never generates). An unregistered script — a not-yet-updated mod, or an external Workshop mod's own custom system — defaults to Misc via `getCategory` rather than being dropped from every category tab.

### ⚔️ 34. Faction Conflict Scoreboard API (`cosmicvaultconflict.lua`)
A generic "who's winning this fight between two factions" combined score, new in v4.0.0. Built after Cosmic War's own War Score & Attrition system proved the idea out — this is separate, general-purpose infrastructure for any OTHER Cosmic mod (or a future Cosmic War mechanic) that wants a shared conflict score without War's specific per-category weighting/capping rules.

```lua
local Conflict = include("cosmicvaultconflict")

Conflict.recordEvent(factionAIndex, factionBIndex, 1)     -- +1 favors factionA
Conflict.recordEvent(factionAIndex, factionBIndex, -25)   -- -25 favors factionB
local score = Conflict.getScore(factionAIndex, factionBIndex)  -- positive = A ahead
Conflict.resetScore(factionAIndex, factionBIndex)         -- once a conflict resolves
```

> [!NOTE]
> Cosmic War's own `getWarScore()` (`cosmicwarbridge.lua`) does NOT run on this — it needs an independent cap on just its kills component that a single combined score can't represent, and migrating working, already-verified logic just to share this primitive wasn't worth the risk. If your mod's conflict-scoring needs are similarly asymmetric, this primitive may not fit either; it's built for the common "one number, both directions" case.

For how these APIs interact with sister mods (Cosmic War, Cosmic Chronicles) when they're installed alongside Cosmic Vault, see `WIKI.md`'s Cross-Mod Synergy section.

---

<div align="center">

[⬆ Back to top](https://github.com/Stormiebox/Cosmic-Vault/wiki/Modder%E2%80%90Guide) · [🌌 README](https://github.com/Stormiebox/Cosmic-Vault) · [⚙️ Wiki](https://github.com/Stormiebox/Cosmic-Vault/wiki/Features)

</div>
