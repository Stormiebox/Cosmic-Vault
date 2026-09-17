
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
        CosmicVaultTerritory.ImportLegacyMaterializations()
        Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")
    end
end

function CosmicVaultTerritoryServer.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if player then
        player:addScriptOnce("data/scripts/player/cv_territory_injector_persistent.lua")
    end
end

-- This compatibility entry point now queues work for an ordinary player-loaded sector.
function CosmicVaultTerritoryServer.flipSectorTerritory(x, y, newFactionIndex)
    if type(x) ~= "number" or type(y) ~= "number" or type(newFactionIndex) ~= "number" then return end

    if CosmicVaultTerritory and CosmicVaultTerritory.resolveSiege then
        CosmicVaultTerritory.resolveSiege(x, y, newFactionIndex)
    end

    include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Queued territory flip in " .. x .. ":" .. y .. " to faction " .. tostring(newFactionIndex))
end


return CosmicVaultTerritoryServer
