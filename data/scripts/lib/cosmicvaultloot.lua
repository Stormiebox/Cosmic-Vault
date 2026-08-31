include("goods")

-- namespace CosmicVaultLoot
CosmicVaultLoot = {}

--- Drops a custom item, weapon, or trade good natively into space
-- @param entityId (string|Uuid) The entity where the loot should spawn
-- @param lootType (string) "good", "weapon", "turret", or "system"
-- @param payload (any) Varies based on type (e.g. goodName, or actual Weapon object)
-- @param amount (int) How many to drop (applies mainly to goods)
-- @param owner (int) Optional faction index of who should own the loot
function CosmicVaultLoot.dropCustomLoot(entityId, lootType, payload, amount, owner)
    if not onServer() then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    local sector = Sector()
    if not sector then return end
    local position = entity.translationf

    -- reservedFor/deniedFor take nil | Faction, never a raw index - vanilla
    -- always passes a Faction object or nil (see cargostash.lua, stash.lua).
    local reservedFaction = owner and Faction(owner) or nil

    if lootType == "good" then
        local g = goods[payload]
        if g then
            -- Sector:dropCargo(position, reservedFor, deniedFor, good, owner, amount)
            sector:dropCargo(position, reservedFaction, nil, g:good(), owner or 0, amount or 1)
        end
    elseif lootType == "weapon" or lootType == "turret" then
        -- payload must be an InventoryTurret or Weapon object
        if payload then
            sector:dropTurret(position, reservedFaction, nil, payload)
        end
    elseif lootType == "system" then
        -- payload must be an SystemUpgradeTemplate
        if payload then
            sector:dropUpgrade(position, reservedFaction, nil, payload)
        end
    end
end

return CosmicVaultLoot
