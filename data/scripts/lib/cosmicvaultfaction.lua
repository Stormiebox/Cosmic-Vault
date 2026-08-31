
-- namespace CosmicVaultFaction
local CosmicVaultFaction = {}

local VAULT_PREFIX = "cosmic_trait_"

-- Ensure a global registry exists for the UI to consume across different script contexts in the same VM
if not _G.CosmicVaultRegisteredTraits then
    _G.CosmicVaultRegisteredTraits = {}
end

--- Registers a new custom faction trait for the vanilla UI
-- @param traitId (string) The unique internal ID of the trait (e.g. "industrial")
-- @param traitName (string) The display name in the UI (e.g. "Industrial")
-- @param descriptions (table) Array of strings acting as tooltips (e.g. {"Produces more goods", "Aggressively defends miners"})
function CosmicVaultFaction.registerCustomTrait(traitId, traitName, descriptions)
    if not traitId then return end
    _G.CosmicVaultRegisteredTraits[traitId] = {
        name = traitName,
        descriptions = descriptions or {}
    }
end

--- Retrieves the registry of custom traits
-- @return table Dictionary of registered traits
function CosmicVaultFaction.getCustomTraits()
    return _G.CosmicVaultRegisteredTraits
end

--- Safely adds a temporary or permanent trait to a faction
-- @param factionIndex (int) The index of the faction
-- @param traitName (string) The name of the trait (e.g. "aggressive", "isolationist")
-- @param value (any) The value of the trait (usually boolean or int)
function CosmicVaultFaction.setTrait(factionIndex, traitName, value)
    if not onServer() then return end
    if not traitName then return end
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
    if not traitName then return nil end
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
    if not delta then return end
    if factionIndex1 == factionIndex2 then return end
    
    local f1 = Faction(factionIndex1)
    local f2 = Faction(factionIndex2)
    if not f1 or not f2 then return end

    local current = f1:getRelations(factionIndex2) or 0
    local newRelation = math.max(-100000, math.min(100000, current + delta))
    
    Galaxy():setFactionRelations(f1, f2, newRelation)

    -- Synergy & Balancing: Mirror relations changes to Alliance if Player
    if f1.isPlayer then
        local p1 = Player(f1.index)
        if p1 and p1.allianceIndex then
            local a1 = Faction(p1.allianceIndex)
            if a1 then
                local aCurrent = a1:getRelations(factionIndex2) or 0
                local aNewRelation = math.max(-100000, math.min(100000, aCurrent + delta))
                Galaxy():setFactionRelations(a1, f2, aNewRelation)
            end
        end
    end
    if f2.isPlayer then
        local p2 = Player(f2.index)
        if p2 and p2.allianceIndex then
            local a2 = Faction(p2.allianceIndex)
            if a2 then
                local aCurrent = f1:getRelations(p2.allianceIndex) or 0
                local aNewRelation = math.max(-100000, math.min(100000, aCurrent + delta))
                Galaxy():setFactionRelations(f1, a2, aNewRelation)
            end
        end
    end
end

return CosmicVaultFaction
