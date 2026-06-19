package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultframework")

-- namespace CosmicVaultCombat
CosmicVaultCombat = CosmicVaultCombat or {}

--[[
    Cosmic Vault Combat API
    Provides tools for advanced RPG damage mechanics such as True Damage,
    Damage Over Time (DoTs), and Healing Over Time (HoTs).
]]

--- Applies direct True Damage natively to an entity, ignoring all armor and shields
-- @param entityId (string|Uuid) The target entity
-- @param amount (number) The amount of raw damage to inflict
-- @param sourceId (string|Uuid) Optional source of the damage
function CosmicVaultCombat.applyTrueDamage(entityId, amount, sourceId)
    if not entityId or not amount then return end
    if not onServer() then return end
    local entity = Entity(entityId)
    if not valid(entity) then return end
    
    local newDurability = entity.durability - amount
    if newDurability <= 0 then
        entity.durability = 0
        -- entity will be destroyed next frame
        if sourceId and valid(Entity(sourceId)) then
            entity:destroy(sourceId)
        else
            entity:destroy(entity.id)
        end
    else
        entity.durability = newDurability
    end
end

--- Inflicts a Damage Over Time (DoT) effect natively to an entity
-- @param entityId (string|Uuid) The target entity
-- @param damageType (string) Cosmetic name for the damage type (e.g. "Burn", "Radiation")
-- @param totalDamage (number) Total damage to inflict over the duration
-- @param durationSeconds (int) How long the DoT lasts in seconds
-- @param sourceId (string|Uuid) Optional source of the damage
function CosmicVaultCombat.applyDoT(entityId, damageType, totalDamage, durationSeconds, sourceId)
    if not entityId or not damageType or not totalDamage or not durationSeconds then return end
    if not onServer() then return end
    local entity = Entity(entityId)
    if not valid(entity) then return end
    
    -- We natively attach the cosmicdot script to the entity
    entity:addScript("data/scripts/entity/cosmicdot.lua", damageType, totalDamage, durationSeconds, sourceId)
end

--- Inflicts a Healing Over Time (HoT) effect natively to an entity
-- @param entityId (string|Uuid) The target entity
-- @param totalHeal (number) Total healing to restore over the duration
-- @param durationSeconds (int) How long the HoT lasts in seconds
function CosmicVaultCombat.applyHoT(entityId, totalHeal, durationSeconds)
    if not entityId or not totalHeal or not durationSeconds then return end
    if not onServer() then return end
    local entity = Entity(entityId)
    if not valid(entity) then return end
    
    -- We natively attach the cosmichot script to the entity
    entity:addScript("data/scripts/entity/cosmichot.lua", totalHeal, durationSeconds)
end

if CosmicVaultFramework and CosmicVaultFramework.registerModule then
    CosmicVaultFramework.registerModule("CosmicVaultCombat", {version = "1.0.0"})
end

return CosmicVaultCombat
