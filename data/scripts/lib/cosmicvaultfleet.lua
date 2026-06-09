package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultFleet
CosmicVaultFleet = {}

--- Clears all orders for a specific ship
-- @param entityId (string|Uuid) The entity to clear orders for
function CosmicVaultFleet.clearOrders(entityId)
    if not onServer() then return end
    local entity = Entity(entityId)
    if not entity then return end
    
    entity:invokeFunction("data/scripts/entity/orderchain.lua", "clearAllOrders")
end

--- Orders a ship to attack all enemies in the sector natively
-- @param entityId (string|Uuid) The entity to order
-- @param clearPrevious (boolean) If true, clears the order chain first
function CosmicVaultFleet.orderAttackEnemies(entityId, clearPrevious)
    if not onServer() then return end
    if clearPrevious then CosmicVaultFleet.clearOrders(entityId) end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    entity:invokeFunction("data/scripts/entity/orderchain.lua", "addAggressiveOrder", true, true)
    entity:invokeFunction("data/scripts/entity/orderchain.lua", "runOrders")
end

--- Orders a ship to escort a target natively
-- @param entityId (string|Uuid) The entity to order
-- @param targetId (string|Uuid) The entity to escort
-- @param clearPrevious (boolean) If true, clears the order chain first
function CosmicVaultFleet.orderEscort(entityId, targetId, clearPrevious)
    if not onServer() then return end
    if clearPrevious then CosmicVaultFleet.clearOrders(entityId) end
    
    local entity = Entity(entityId)
    local target = Entity(targetId)
    if not entity or not target then return end
    
    entity:invokeFunction("data/scripts/entity/orderchain.lua", "addEscortOrder", nil, target.factionIndex, target.name)
    entity:invokeFunction("data/scripts/entity/orderchain.lua", "runOrders")
end

--- Orders a ship to jump to another sector natively
-- @param entityId (string|Uuid) The entity to order
-- @param x (int) X coordinate
-- @param y (int) Y coordinate
function CosmicVaultFleet.orderJump(entityId, x, y)
    if not onServer() then return end
    CosmicVaultFleet.clearOrders(entityId)
    
    local entity = Entity(entityId)
    if not entity then return end
    
    entity:invokeFunction("data/scripts/entity/orderchain.lua", "addJumpOrder", x, y)
    entity:invokeFunction("data/scripts/entity/orderchain.lua", "runOrders")
end

return CosmicVaultFleet
