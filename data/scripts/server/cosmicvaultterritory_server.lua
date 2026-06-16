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

-- This function is called by the API when a sector is briefly loaded to flip its stations
function CosmicVaultTerritoryServer.flipSectorTerritory(x, y, newFactionIndex)
    local sector = Sector()
    local cx, cy = sector:getCoordinates()

    if cx ~= x or cy ~= y then return end -- Failsafe

    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, station in pairs(stations) do
        -- Only flip stations that are owned by AI factions
        local currentFaction = Faction(station.factionIndex)
        if currentFaction and currentFaction.isAIFaction then
            station.factionIndex = newFactionIndex
        end
    end
    local sectorName = "\\s(" .. x .. ":" .. y .. ")"
    local factionName = Faction(newFactionIndex) and Faction(newFactionIndex).name or "an Unknown Faction"

    print("[Cosmic Vault] Flipped stations in " .. x .. ":" .. y .. " to faction " .. tostring(newFactionIndex))

    local CosmicVaultNews = include("cosmicvaultnews")
    if CosmicVaultNews and CosmicVaultNews.publishArticle then
        CosmicVaultNews.publishArticle({
            title = "Territory Conquered",
            content = "The sector " .. sectorName .. " has been successfully annexed by " .. factionName .. ". The galaxy borders have officially shifted.",
            category = "War"
        })
    end
end


function getUpdateInterval(...)
    if CosmicVaultTerritoryServer.getUpdateInterval then return CosmicVaultTerritoryServer.getUpdateInterval(...) end
end
function updateServer(...)
    if CosmicVaultTerritoryServer.updateServer then return CosmicVaultTerritoryServer.updateServer(...) end
end
