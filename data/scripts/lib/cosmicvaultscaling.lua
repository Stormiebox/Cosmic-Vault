
local CosmicVaultScaling = {}

--[[
    Cosmic Vault Scaling API
    Provides advanced mathematical analysis of a sector's combat capabilities
    to dynamically scale invasion events and encounters.
]]

--- Scans all entities in the sector and calculates the total defensive strength against an invading faction.
-- @param invaderFactionIndex (int) The faction index of the invaders. Anyone not friendly to them is a defender.
-- @return table { volume = totalVolume, firePower = totalOmicron, entityCount = count }
function CosmicVaultScaling.calculateSectorDefenderStrength(invaderFactionIndex)
    local sector = Sector()
    local totalVolume = 0
    local totalFirePower = 0
    local count = 0
    
    if not sector then return {volume=0, firePower=0, entityCount=0} end
    
    local galaxy = Galaxy()
    local invaderFaction = Faction(invaderFactionIndex)
    
    local entities = {sector:getEntitiesByType(EntityType.Ship)}
    for _, s in pairs({sector:getEntitiesByType(EntityType.Station)}) do
        table.insert(entities, s)
    end
    
    for _, entity in pairs(entities) do
        if entity.factionIndex and entity.factionIndex > 0 then
            -- Determine if this entity is hostile or neutral to the invader.
            -- If the invader hates them, they are a defender.
            -- Faction() can return nil for an eradicated/invalid index, and
            -- passing nil into getFactionRelations crashes, so both sides
            -- must be guarded before the call.
            local defenderFaction = Faction(entity.factionIndex)
            if invaderFaction and defenderFaction then
                local rel = galaxy:getFactionRelations(invaderFaction, defenderFaction)
                if rel < -10000 or entity.playerOwned or entity.allianceOwned then
                    count = count + 1
                    totalVolume = totalVolume + (entity.volume or 0)
                    totalFirePower = totalFirePower + (entity.firePower or 0)
                end
            end
        end
    end
    
    -- Stations can have massively inflated volume compared to their actual combat threat.
    -- We cap individual station volume contribution to prevent spawning completely unkillable invader counts,
    -- but still scale significantly.
    
    -- Synergy: Faction Traits Modifying Siege Scaling
    local controllingFaction = galaxy:getControllingFaction(sector:getCoordinates())
    if controllingFaction and type(controllingFaction) ~= "number" and controllingFaction.index and controllingFaction.index > 0 then
        if controllingFaction and controllingFaction:getValue("cosmic_trait_cw_entrenched") == 1 then
            totalVolume = totalVolume * 1.3
            totalFirePower = totalFirePower * 1.3
        end
    end
    
    -- Prevent infinite deathball scaling that crashes the server
    if totalVolume > 500000000 then
        totalVolume = 500000000
    end

    return {
        volume = totalVolume,
        firePower = totalFirePower,
        entityCount = count
    }
end

--- Given the defender's stats, calculates how many ships and what volume multiplier the invaders need.
-- @param defenderStats (table) from calculateSectorDefenderStrength
-- @param baseShipVolume (number) The average volume of a single standard ship generated here
-- @param targetPercentage (number) e.g., 1.0 for 100% match, 1.5 for 150% match
-- @return table { count = numberOfShips, volumeMultiplier = multiplierPerShip }
function CosmicVaultScaling.calculateInvaderSpawnParams(defenderStats, baseShipVolume, targetPercentage)
    targetPercentage = targetPercentage or 1.0
    
    local targetVolume = defenderStats.volume * targetPercentage
    if targetVolume <= 0 then targetVolume = baseShipVolume * 3 end -- minimum spawn
    
    -- How many ships would this be at base volume?
    local rawCount = targetVolume / baseShipVolume
    
    local spawnCount = math.floor(rawCount)
    local volumeMultiplier = 1.0
    
    -- Limit the max number of ships to avoid server lag (e.g., max 15 ships per wave)
    if spawnCount > 15 then
        spawnCount = 15
        -- If we cap the count, we must increase the volume (size/health) of each ship to compensate
        volumeMultiplier = rawCount / 15
    elseif spawnCount < 4 then
        spawnCount = 4
        volumeMultiplier = rawCount / 4
    end
    
    -- Cap the volume multiplier to avoid physically absurd ships
    if volumeMultiplier > 10.0 then volumeMultiplier = 10.0 end
    
    return {
        count = spawnCount,
        volumeMultiplier = volumeMultiplier
    }
end

return CosmicVaultScaling
