package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include("SectorGenerator")

local CosmicVaultAnomalies = {}

-- Spawns a physical anomaly object in the sector.
function CosmicVaultAnomalies.spawnAnomaly(x, y, anomalyType, position)
    local sector = Sector()
    local cx, cy = sector:getCoordinates()
    
    if cx ~= x or cy ~= y then
        include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Cannot spawn anomaly: Sector coords mismatch")
        return nil
    end
    
    local generator = SectorGenerator(x, y)
    position = position or generator:getPositionInSector(10000)
    
    local entity
    if anomalyType == "PrecursorWreck" then
        local faction = Galaxy():getNearestFaction(x, y) or Galaxy():getPirateFaction(0)
        local plan = PlanGenerator.makeShipPlan(faction, Balancing_GetSectorShipVolume(x, y) * 5, nil, Material(MaterialType.Xanion))
        entity = sector:createWreckage(plan, position)
        entity.title = "Ancient Precursor Wreck"
        entity:addScriptOnce("data/scripts/entity/cv_anomaly_wreck.lua")
        
    elseif anomalyType == "SpatialRift" then
        -- Generate an invincible asteroid as the base for the rift
        local desc = AsteroidDescriptor()
        desc.position = position
        desc:setPlan(generator:createAsteroidPlan(200, Material(MaterialType.Iron)))
        entity = sector:createEntity(desc)
        entity.title = "Unstable Spatial Rift"
        entity.invincible = true
        entity:addScriptOnce("data/scripts/entity/cv_anomaly_rift.lua")
    else
        include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Unknown anomaly type: " .. tostring(anomalyType))
    end
    
    return entity
end

return CosmicVaultAnomalies
