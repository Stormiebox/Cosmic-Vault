package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultframework")
local SectorSpecifics = include("sectorspecifics")

-- namespace CosmicVaultEconomy
CosmicVaultEconomy = CosmicVaultEconomy or {}

--[[
    Cosmic Vault Economy API
    Allows reading live market data and triggering dynamic economic events natively.
]]

--- Registers a dynamic price fluctuation hook for a specific good
-- @param goodName (string) The name of the good (e.g., "Contraband")
-- @param scriptName (string) The script containing the callback (e.g., "mymod.lua")
-- @param functionName (string) The name of the callback function. It must return a float multiplier.
function CosmicVaultEconomy.registerPriceHook(goodName, scriptName, functionName)
    if not goodName or not scriptName or not functionName then return end
    if onServer() then
        -- We sanitize the good name to safely use it as a Server value key
        local key = "CVE_PriceHook_" .. goodName:gsub("%s+", "_")
        local existing = Server():getValue(key)
        local entry = scriptName .. "::" .. functionName
        
        if existing then
            if not string.find(existing, entry, 1, true) then
                Server():setValue(key, existing .. "|" .. entry)
            end
        else
            Server():setValue(key, entry)
        end
    else
        invokeServerFunction("registerPriceHook", goodName, scriptName, functionName)
    end
end
callable(CosmicVaultEconomy, "registerPriceHook")

--- Gets live supply and demand info for a sector
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @return (table|nil) Supply and demand data
function CosmicVaultEconomy.GetSupplyDemandInfo(x, y)
    if not x or not y then return nil end
    local sector = Sector()
    if not sector then return nil end
    
    local sx, sy = sector:getCoordinates()
    if sx == x and sy == y then
        -- We are in the sector, we can read directly
        local data = {}
        local factories = {sector:getEntitiesByComponent(ComponentType.Factory)}
        for _, factory in pairs(factories) do
            local fac = Factory(factory)
            for i = 0, fac.numSold - 1 do
                local good = fac:getSoldGood(i)
                data[good.name] = (data[good.name] or 0) + fac:getStock(good.name)
            end
        end
        return data
    end
    
    return nil -- To properly query unloaded sectors requires simulating or using economyinfo.lua cache
end

--- Triggers a dynamic market event
-- @param goodName (string) The good name
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param radius (number) Event radius
-- @param eventType (string) 'boom' or 'crash'
-- @return (boolean) Success
function CosmicVaultEconomy.TriggerMarketEvent(goodName, x, y, radius, eventType)
    if not goodName or not x or not y or not radius or not eventType then return false end
    -- eventType: "boom" or "crash"
    -- This natively interacts with CosmicVaultNews if available to broadcast to players
    if CosmicVaultFramework.isRegistered("CosmicVaultNews") then
        local cvn = include("cosmicvaultnews")
        if cvn and cvn.broadcast then
            local articleTitle = ""
            local articleBody = ""
            
            if eventType == "boom" then
                articleTitle = string.format("Economic Boom: %s Demand Skyrockets!", goodName)
                articleBody = string.format("Traders in the vicinity of (%d:%d) are paying premium credits for %s.", x, y, goodName)
            else
                articleTitle = string.format("Market Crash: %s Plummets!", goodName)
                articleBody = string.format("A severe surplus around (%d:%d) has caused the value of %s to crash.", x, y, goodName)
            end
            
            cvn.publishArticle({title=articleTitle, content=articleBody, category="Economy"})
        end
    end
    
    -- Future implementation: Find economy manager and manipulate multiplier directly.
    return true
end

if CosmicVaultFramework and CosmicVaultFramework.registerModule then
    CosmicVaultFramework.registerModule("CosmicVaultEconomy", {version = "1.0.0"})
end

return CosmicVaultEconomy
