package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultframework")
local SectorSpecifics = include("sectorspecifics")

-- namespace CosmicVaultEconomy
CosmicVaultEconomy = CosmicVaultEconomy or {}

--[[
    Cosmic Vault Economy API
    Allows reading live market data and triggering dynamic economic events natively.
]]

function CosmicVaultEconomy.GetSupplyDemandInfo(x, y)
    local sector = Sector()
    if not sector then return nil end
    
    if sector:getCoordinates() == x and sector:getCoordinates() == y then
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

function CosmicVaultEconomy.TriggerMarketEvent(goodName, x, y, radius, eventType)
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
