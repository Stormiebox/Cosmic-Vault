
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

    -- Queue the territory flip for the next time a player enters the sector.
    -- Server():setValue() only supports bool/number/string/nil, and every reader
    -- (CosmicVaultTerritory.resolveSiege and cv_territory_injector_persistent.lua)
    -- expects the "x__y__factionIndex," string queue format - delegate to the
    -- shared implementation instead of maintaining a second, incompatible format.
    if CosmicVaultTerritory and CosmicVaultTerritory.resolveSiege then
        CosmicVaultTerritory.resolveSiege(x, y, newFactionIndex)
    end

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


return CosmicVaultTerritoryServer
