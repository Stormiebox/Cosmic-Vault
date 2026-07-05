package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicVaultTerritory = include("cosmicvaultterritory")

-- namespace CosmicVaultTerritoryServer
CosmicVaultTerritoryServer = {}

function CosmicVaultTerritoryServer.getUpdateInterval()
    return 60 -- Run once per minute to check siege timers
end

function CosmicVaultTerritoryServer.updateServer(timeStep)
    if CosmicVaultTerritory and CosmicVaultTerritory.updateServer then
        CosmicVaultTerritory.updateServer(timeStep)
    end
end

function CosmicVaultTerritoryServer.initialize()
    if onServer() then
        Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")
    end
end

function CosmicVaultTerritoryServer.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if player then
        player:addScriptOnce("data/scripts/player/cv_territory_injector_persistent.lua")
    end
end

-- This function is called by the API when a sector is briefly loaded to flip its stations
function CosmicVaultTerritoryServer.flipSectorTerritory(x, y, newFactionIndex)
    if type(x) ~= "number" or type(y) ~= "number" or type(newFactionIndex) ~= "number" then return end
    
    -- Queue the territory flip for the next time a player enters the sector
    local pending = Server():getValue("CosmicVault_PendingFlips")
    if type(pending) ~= "table" then pending = {} end
    
    local key = tostring(x) .. "_" .. tostring(y)
    pending[key] = newFactionIndex
    Server():setValue("CosmicVault_PendingFlips", pending)

    local sectorName = "\\s(" .. x .. ":" .. y .. ")"
    local factionName = Faction(newFactionIndex) and Faction(newFactionIndex).name or "an Unknown Faction"
    
    include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Queued territory flip in " .. x .. ":" .. y .. " to faction " .. tostring(newFactionIndex))
    
    local CosmicVaultNews = include("cosmicvaultnews")
    if CosmicVaultNews and CosmicVaultNews.publishArticle then
        CosmicVaultNews.publishArticle({
            title = "Territory Conquered",
            content = "The sector " .. sectorName .. " has been successfully annexed by " .. factionName .. ". The galaxy borders have officially shifted.",
            category = "War"
        })
    end
end


function initialize(...)
    if CosmicVaultTerritoryServer.initialize then return CosmicVaultTerritoryServer.initialize(...) end
end
function onPlayerLogIn(...)
    if CosmicVaultTerritoryServer.onPlayerLogIn then return CosmicVaultTerritoryServer.onPlayerLogIn(...) end
end
function getUpdateInterval(...)
    if CosmicVaultTerritoryServer.getUpdateInterval then return CosmicVaultTerritoryServer.getUpdateInterval(...) end
end
function updateServer(...)
    if CosmicVaultTerritoryServer.updateServer then return CosmicVaultTerritoryServer.updateServer(...) end
end

return CosmicVaultTerritoryServer
