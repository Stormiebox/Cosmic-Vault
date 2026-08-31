include("randomext")
local ShipGenerator = include("shipgenerator")

-- namespace CosmicVaultEncounter
CosmicVaultEncounter = {}

--- Spawns a custom encounter dynamically without altering vanilla sectorspecifics
-- @param factionId (int) The faction index to spawn ships for
-- @param volume (number) The total volume of the ships to spawn
-- @param numShips (int) Number of ships to spawn
-- @param spawnMatrix (Matrix) The coordinate matrix where the encounter begins
-- @param setAggressive (boolean) If true, the spawned ships will attack players immediately
-- @return table List of spawned entities
function CosmicVaultEncounter.spawnAmbush(factionId, volume, numShips, spawnMatrix, setAggressive)
    if not onServer() then return {} end

    local faction = Faction(factionId)
    if not faction then return {} end
    
    local spawnedShips = {}
    
    local pos = spawnMatrix and Matrix(spawnMatrix) or MatrixLookUpPosition(-vec3(0, 1, 0), vec3(1, 0, 0), vec3(random():getInt(-500, 500), random():getInt(-500, 500), random():getInt(-500, 500)))

    for i = 1, numShips do
        local ship = ShipGenerator.createMilitaryShip(faction, pos, volume)
        if ship then
            if setAggressive then
                ship.title = "Ambush " .. ship.title
                local ai = ShipAI(ship.index)
                if ai then
                    ai:setAggressive()
                end
            end
            table.insert(spawnedShips, ship)
        end
        -- Stagger spawns slightly
        pos.pos = pos.pos + vec3(random():getInt(-50, 50), random():getInt(-50, 50), random():getInt(-50, 50))
    end

    return spawnedShips
end

--- Broadcasts a localized chat message or radio transmission to players in the sector
-- @param sender (string) The name of the sender (e.g. "Pirate Captain")
-- @param message (string) The text message
-- @param isRadio (boolean) If true, shows up as a popup transmission
function CosmicVaultEncounter.broadcastEncounterMessage(sender, message, isRadio)
    if not onServer() then return end

    local sector = Sector()
    if not sector then return end
    
    if isRadio then
        sector:broadcastChatMessage(sender, ChatMessageType.Chatter, message)
    else
        sector:broadcastChatMessage(sender, ChatMessageType.Normal, message)
    end
end

return CosmicVaultEncounter
