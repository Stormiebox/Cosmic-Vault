package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultBuffs
CosmicVaultBuffs = {}

--- Applies a temporary stat buff or debuff natively to an entity
-- @param entityId (string|Uuid) The target entity
-- @param statName (string) The stat to modify (e.g. "Velocity", "Shield", "Damage")
-- @param multiplier (number) The multiplier (e.g. 0.5 for half speed, 2.0 for double damage)
-- @param durationSeconds (int) How long the buff should last
function CosmicVaultBuffs.applyBuff(entityId, statName, multiplier, durationSeconds)
    if not onServer() then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    -- We natively attach the cosmicbuff script to the entity.
    -- The script will self-terminate when the duration expires.
    entity:addScript("data/scripts/entity/cosmicbuff.lua", statName, multiplier, durationSeconds)
end

--- Applies a permanent stat multiplier factor natively to an entity
-- @param entityId (string|Uuid) The target entity
-- @param statName (int) The StatsBonuses Enum value (e.g. StatsBonuses.ShieldDurability)
-- @param factor (number) The base factor (e.g. 5.0 for +500% increase)
function CosmicVaultBuffs.applyPermanentFactor(entityId, statName, factor)
    if not onServer() then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    entity:addMultiplyableBias(statName, factor)
end

--- Removes all active Cosmic Buffs natively from an entity
-- @param entityId (string|Uuid) The target entity
function CosmicVaultBuffs.clearBuffs(entityId)
    if not onServer() then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    -- Natively remove the script from the entity block
    while entity:hasScript("data/scripts/entity/cosmicbuff.lua") do
        entity:removeScript("data/scripts/entity/cosmicbuff.lua")
    end
end

--- Sets the global Ascendancy Tier for a player or alliance natively
-- @param factionIndex (int) The faction to modify
-- @param tier (int) The tier level
function CosmicVaultBuffs.setGlobalTier(factionIndex, tier)
    if not onServer() then return end
    local faction = Faction(factionIndex)
    if not faction then return end
    faction:setValue("cv_ascendancy_global_tier", tier)
end

--- Retrieves the current global Ascendancy Tier for a faction
-- @param factionIndex (int) The faction to query
-- @return int The current tier, or 0 if none
function CosmicVaultBuffs.getGlobalTier(factionIndex)
    local faction = Faction(factionIndex)
    if not faction then return 0 end
    return faction:getValue("cv_ascendancy_global_tier") or 0
end

return CosmicVaultBuffs
