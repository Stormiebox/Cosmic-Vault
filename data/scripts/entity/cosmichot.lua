package.path = package.path .. ";data/scripts/lib/?.lua"

local totalHeal = 0
local durationSeconds = 0
local healPerTick = 0
local ticksRemaining = 0

-- Called when the script is added
function initialize(hTotal, hDuration)
    if onServer() then
        totalHeal = hTotal or 100
        durationSeconds = hDuration or 5
        
        if durationSeconds <= 0 then 
            terminate() 
            return 
        end
        
        ticksRemaining = math.floor(durationSeconds)
        healPerTick = totalHeal / ticksRemaining
    end
end

function getUpdateInterval()
    return 1.0
end

-- Tick every second automatically via the Engine
function updateServer(timeStep)
    if ticksRemaining <= 0 then
        terminate()
        return
    end
    
    local entity = Entity()
    if not valid(entity) then
        terminate()
        return
    end
    
    -- Apply healing (Prioritize hull, then spill over to shields)
    local remainingHeal = healPerTick
    local hullMissing = entity.maxDurability - entity.durability
    
    if hullMissing > 0 then
        local healAmount = math.min(hullMissing, remainingHeal)
        if entity.heal then
            entity:heal(healAmount)
        else
            entity.durability = entity.durability + healAmount
        end
        remainingHeal = remainingHeal - healAmount
    end
    
    if remainingHeal > 0 and entity.shieldMaxDurability > 0 then
        local shieldMissing = entity.shieldMaxDurability - entity.shieldDurability
        if shieldMissing > 0 then
            local healAmount = math.min(shieldMissing, remainingHeal)
            entity.shieldDurability = entity.shieldDurability + healAmount
        end
    end
    
    ticksRemaining = ticksRemaining - 1
    
    if ticksRemaining <= 0 then
        terminate()
    end
end

function secure()
    return {
        totalHeal = totalHeal,
        durationSeconds = durationSeconds,
        healPerTick = healPerTick,
        ticksRemaining = ticksRemaining
    }
end

function restore(data)
    totalHeal = data.totalHeal or 0
    durationSeconds = data.durationSeconds or 0
    healPerTick = data.healPerTick or 0
    ticksRemaining = data.ticksRemaining or 0
    
    if ticksRemaining <= 0 then
        terminate()
    end
end
