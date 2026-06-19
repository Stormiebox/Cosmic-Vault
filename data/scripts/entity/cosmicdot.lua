package.path = package.path .. ";data/scripts/lib/?.lua"

local damageType = ""
local totalDamage = 0
local durationSeconds = 0
local sourceId = nil
local damagePerTick = 0
local ticksRemaining = 0

-- Called when the script is added
function initialize(dType, dTotal, dDuration, dSource)
    damageType = dType or "Unknown"
    totalDamage = dTotal or 10
    durationSeconds = dDuration or 5
    sourceId = dSource
    
    if durationSeconds <= 0 then 
        terminate() 
        return 
    end
    
    ticksRemaining = math.floor(durationSeconds)
    damagePerTick = totalDamage / ticksRemaining
    
    if onServer() then
        deferredCallback(1.0, "tickDoT")
    end
end

-- Tick every second
function tickDoT()
    if ticksRemaining <= 0 then
        terminate()
        return
    end
    
    local entity = Entity()
    if not valid(entity) then
        terminate()
        return
    end
    
    -- Apply damage
    local src = entity.id
    if sourceId then src = sourceId end
    
    entity:inflictDamage(damagePerTick, 0, 0, src) -- Using inflictDamage(amount, damageSource, damageType, sourceEntity)
    
    ticksRemaining = ticksRemaining - 1
    
    if ticksRemaining > 0 then
        deferredCallback(1.0, "tickDoT")
    else
        terminate()
    end
end

function getUpdateInterval()
    return 1.0
end
