package.path = package.path .. ";data/scripts/lib/?.lua"

local damageType = 0
local totalDamage = 0
local durationSeconds = 0
local sourceId = nil
local damagePerTick = 0
local ticksRemaining = 0

-- Called when the script is added
function initialize(dType, dTotal, dDuration, dSource)
    if onServer() then
        damageType = dType or DamageType.Physical
        totalDamage = dTotal or 10
        durationSeconds = dDuration or 5
        sourceId = dSource
        
        if durationSeconds <= 0 then 
            terminate() 
            return 
        end
        
        ticksRemaining = math.floor(durationSeconds)
        damagePerTick = totalDamage / ticksRemaining
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
    
    local durability = Durability(entity.id)
    if not valid(durability) then
        terminate()
        return
    end
    
    -- Apply damage
    local src = entity.id
    if sourceId then
        if type(sourceId) == "string" then
            src = Uuid(sourceId)
        else
            src = sourceId
        end
    end
    
    durability:inflictDamage(damagePerTick, DamageSource.Arbitrary, damageType, src)
    
    ticksRemaining = ticksRemaining - 1
    
    if ticksRemaining <= 0 then
        terminate()
    end
end

function secure()
    return {
        damageType = damageType,
        totalDamage = totalDamage,
        durationSeconds = durationSeconds,
        sourceId = sourceId,
        damagePerTick = damagePerTick,
        ticksRemaining = ticksRemaining
    }
end

function restore(data)
    damageType = data.damageType or DamageType.Physical
    totalDamage = data.totalDamage or 0
    durationSeconds = data.durationSeconds or 0
    sourceId = data.sourceId
    damagePerTick = data.damagePerTick or 0
    ticksRemaining = data.ticksRemaining or 0
    
    if ticksRemaining <= 0 then
        terminate()
    end
end
