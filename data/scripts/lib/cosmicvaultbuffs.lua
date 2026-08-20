package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultBuffs
CosmicVaultBuffs = {}

--- Applies a temporary stat buff or debuff natively to an entity
-- @param entityId (string|Uuid) The target entity
-- @param statName (string) The stat to modify (e.g. "Velocity", "Shield", "Damage")
-- @param multiplier (number) The multiplier (e.g. 0.5 for half speed, 2.0 for double damage)
-- @param durationSeconds (int) How long the buff should last
-- @param buffId (string) Optional unique ID for early termination
function CosmicVaultBuffs.applyBuff(entityId, statName, multiplier, durationSeconds, buffId)
    if not onServer() then return end
    if type(statName) ~= "string" then return end
    if type(multiplier) ~= "number" then return end
    if type(durationSeconds) ~= "number" then return end
    if buffId and type(buffId) ~= "string" then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    -- We natively attach the cosmicbuff script to the entity.
    -- The script will self-terminate when the duration expires.
    entity:addScript("data/scripts/entity/cosmicbuff.lua", statName, multiplier, durationSeconds, buffId or "")
end

--- Terminates a specific buff early by its unique ID
-- @param entityId (string|Uuid) The target entity
-- @param buffId (string) The unique ID of the buff to terminate
function CosmicVaultBuffs.terminateBuff(entityId, buffId)
    if not onServer() or type(buffId) ~= "string" or buffId == "" then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    local scripts = entity:getScripts()
    for index, path in pairs(scripts) do
        if type(path) == "string" and string.find(path, "cosmicbuff.lua") then
            entity:invokeFunction(index, "terminateBuffById", buffId)
        end
    end
end

--- Refreshes the duration of a specific buff by its unique ID
-- @param entityId (string|Uuid) The target entity
-- @param buffId (string) The unique ID of the buff to refresh
-- @return (boolean) True if successfully refreshed, false otherwise
function CosmicVaultBuffs.refreshBuff(entityId, buffId)
    if not onServer() or type(buffId) ~= "string" or buffId == "" then return false end
    
    local entity = Entity(entityId)
    if not entity then return false end
    
    local refreshed = false
    local scripts = entity:getScripts()
    for index, path in pairs(scripts) do
        if type(path) == "string" and string.find(path, "cosmicbuff.lua") then
            local status, matched = entity:invokeFunction(index, "refreshBuffById", buffId)
            if status == 0 and matched then
                refreshed = true
                break
            end
        end
    end
    
    return refreshed
end

--- Applies a permanent stat multiplier factor natively to an entity
-- @param entityId (string|Uuid) The target entity
-- @param statName (int) The StatsBonuses Enum value (e.g. StatsBonuses.ShieldDurability)
-- @param factor (number) The base factor (e.g. 5.0 for +500% increase)
function CosmicVaultBuffs.applyPermanentFactor(entityId, statName, factor)
    if not onServer() then return end
    if type(statName) ~= "number" then return end
    if type(factor) ~= "number" then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    entity:addMultiplyableBias(statName, factor)
end

--- Removes a permanent stat multiplier factor natively from an entity
-- @param entityId (string|Uuid) The target entity
-- @param statName (int) The StatsBonuses Enum value (e.g. StatsBonuses.ShieldDurability)
function CosmicVaultBuffs.removePermanentFactor(entityId, statName)
    if not onServer() then return end
    if type(statName) ~= "number" then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    entity:removeMultiplyableBias(statName)
end

--- Applies a permanent base multiplier natively to an entity
-- @param entityId (string|Uuid) The target entity
-- @param statName (int) The StatsBonuses Enum value (e.g. StatsBonuses.ShieldDurability)
-- @param factor (number) The base multiplier (e.g. 0.1 for +10% increase)
function CosmicVaultBuffs.addPermanentBaseMultiplier(entityId, statName, factor)
    if not onServer() then return end
    if type(statName) ~= "number" then return end
    if type(factor) ~= "number" then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    entity:addBaseMultiplier(statName, factor)
end

--- Removes a permanent base multiplier natively from an entity
-- @param entityId (string|Uuid) The target entity
-- @param statName (int) The StatsBonuses Enum value (e.g. StatsBonuses.ShieldDurability)
function CosmicVaultBuffs.removePermanentBaseMultiplier(entityId, statName)
    if not onServer() then return end
    if type(statName) ~= "number" then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    entity:removeBaseMultiplier(statName)
end

--- Removes all active Cosmic Buffs natively from an entity
-- @param entityId (string|Uuid) The target entity
function CosmicVaultBuffs.clearBuffs(entityId)
    if not onServer() then return end
    
    local entity = Entity(entityId)
    if not entity then return end
    
    -- Natively remove the script from the entity block
    local safety = 0
    while entity:hasScript("data/scripts/entity/cosmicbuff.lua") and safety < 100 do
        entity:removeScript("data/scripts/entity/cosmicbuff.lua")
        safety = safety + 1
    end
end

--- Sets the global Ascendancy Tier for a player or alliance natively
-- @param factionIndex (int) The faction to modify
-- @param tier (int) The tier level
function CosmicVaultBuffs.setGlobalTier(factionIndex, tier)
    if not onServer() then return end
    if type(factionIndex) ~= "number" then return end
    if type(tier) ~= "number" then return end
    local faction = Faction(factionIndex)
    if not faction then return end
    faction:setValue("cv_ascendancy_global_tier", tier)
end

--- Retrieves the current global Ascendancy Tier for a faction
-- @param factionIndex (int) The faction to query
-- @return int The current tier, or 0 if none
function CosmicVaultBuffs.getGlobalTier(factionIndex)
    if type(factionIndex) ~= "number" then return 0 end
    local faction = Faction(factionIndex)
    if not faction then return 0 end
    return faction:getValue("cv_ascendancy_global_tier") or 0
end

--- Calculates the dynamic multiplier for Living Relics based on distance to core and war heat.
-- Automatically reads from Cosmic War's global server state to prevent hard-dependencies.
-- @param entityId (Entity|Uuid|string) The entity to base the calculation on.
-- @return number The final multiplier (e.g. 1.0 to 2.5)
function CosmicVaultBuffs.getDynamicRelicMultiplier(entityId)
    local distMultiplier = 1.0
    local x, y = Sector():getCoordinates()
    if x and y then
        local dist = math.sqrt(x * x + y * y)
        distMultiplier = 1.0 + (math.max(0, 500 - dist) / 250)
    end
    
    local entity = Entity(entityId)
    if not entity then return math.min(2.5, distMultiplier) end
    
    local factionIndex = entity.factionIndex
    local warMultiplier = 1.0
    
    local server = Server()
    if server then
        local snapshotStr = server:getValue("cw_war_heat_snapshot")
        if type(snapshotStr) == "string" and snapshotStr ~= "" then
            for pair in string.gmatch(snapshotStr, "([^,]+)") do
                local idxStr, heatStr = string.match(pair, "(%d+):([%d%.]+)")
                if idxStr and tonumber(idxStr) == factionIndex and heatStr then
                    local heat = tonumber(heatStr) or 0
                    warMultiplier = 1.0 + (heat * 1.5)
                    break
                end
            end
        end
    end
    
    return math.min(2.5, distMultiplier * warMultiplier)
end

return CosmicVaultBuffs
