package.path = package.path .. ";data/scripts/lib/?.lua"

local totalHeal = 0
local durationSeconds = 0
local healPerTick = 0
local ticksRemaining = 0

-- Called when the script is added
function initialize(hTotal, hDuration)
    totalHeal = hTotal or 100
    durationSeconds = hDuration or 5
    
    if durationSeconds <= 0 then 
        terminate() 
        return 
    end
    
    ticksRemaining = math.floor(durationSeconds)
    healPerTick = totalHeal / ticksRemaining
    
    if onServer() then
        deferredCallback(1.0, "tickHoT")
    end
end

-- Tick every second
function tickHoT()
    if ticksRemaining <= 0 then
        terminate()
        return
    end
    
    local entity = Entity()
    if not valid(entity) then
        terminate()
        return
    end
    
    -- Apply healing (Prioritize hull, then shields)
    local hullMissing = entity.maxDurability - entity.durability
    if hullMissing > 0 then
        local healAmount = math.min(hullMissing, healPerTick)
        entity.durability = entity.durability + healAmount
    elseif entity.shieldMaxDurability > 0 then
        local shieldMissing = entity.shieldMaxDurability - entity.shieldDurability
        if shieldMissing > 0 then
            local healAmount = math.min(shieldMissing, healPerTick)
            entity.shieldDurability = entity.shieldDurability + healAmount
        end
    end
    
    ticksRemaining = ticksRemaining - 1
    
    if ticksRemaining > 0 then
        deferredCallback(1.0, "tickHoT")
    else
        terminate()
    end
end

function getUpdateInterval()
    return 1.0
end
