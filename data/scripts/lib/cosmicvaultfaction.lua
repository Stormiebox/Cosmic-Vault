package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultFaction
CosmicVaultFaction = {}

local VAULT_PREFIX = "cosmic_trait_"

--- Safely adds a temporary or permanent trait to a faction
-- @param factionIndex (int) The index of the faction
-- @param traitName (string) The name of the trait (e.g. "aggressive", "isolationist")
-- @param value (any) The value of the trait (usually boolean or int)
function CosmicVaultFaction.setTrait(factionIndex, traitName, value)
    if not onServer() then return end
    local faction = Faction(factionIndex)
    if not faction then return end
    
    local key = VAULT_PREFIX .. traitName
    faction:setValue(key, value)
end

--- Retrieves a trait from a faction natively
-- @param factionIndex (int) The index of the faction
-- @param traitName (string) The name of the trait
-- @return any The value of the trait, or nil if not found
function CosmicVaultFaction.getTrait(factionIndex, traitName)
    local faction = Faction(factionIndex)
    if not faction then return nil end
    
    local key = VAULT_PREFIX .. traitName
    return faction:getValue(key)
end

--- Safely modifies relations without resetting them completely, clamping to valid values
-- @param factionIndex1 (int) Index of first faction
-- @param factionIndex2 (int) Index of second faction
-- @param delta (int) Amount to change relations by
function CosmicVaultFaction.changeRelations(factionIndex1, factionIndex2, delta)
    if not onServer() then return end
    local f1 = Faction(factionIndex1)
    local f2 = Faction(factionIndex2)
    if not f1 or not f2 then return end

    local current = f1:getRelations(factionIndex2) or 0
    local newRelation = math.max(-100000, math.min(100000, current + delta))
    
    f1:setRelations(factionIndex2, newRelation)
end

return CosmicVaultFaction
