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
