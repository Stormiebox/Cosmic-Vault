package.path = package.path .. ";data/scripts/lib/?.lua"

local targetStat = ""
local statMultiplier = 1.0
local duration = 0
local timeActive = 0

-- This is a background entity script that dynamically alters stats and deletes itself.
-- It avoids needing to overwrite the core vanilla ship update loops.

function initialize(statName, multiplier, durationSeconds)
    if onServer() then
        targetStat = statName or ""
        statMultiplier = multiplier or 1.0
        duration = durationSeconds or 0
        timeActive = 0
    end
end

function getUpdateInterval()
    return 1.0 -- Check every second
end

function updateServer(timeStep)
    timeActive = timeActive + timeStep
    
    if timeActive >= duration then
        -- Buff expired, natively delete this script off the entity
        terminate()
    end
end

-- Hook into Avorion's native stat calculation engine
function onBaseMultiplierCalculated(entity, statModifier)
    if targetStat == "Velocity" then
        statModifier:modifyBaseMultiplier(StatsBonuses.Velocity, statMultiplier)
    elseif targetStat == "Shield" then
        statModifier:modifyBaseMultiplier(StatsBonuses.ShieldDurability, statMultiplier)
    elseif targetStat == "Damage" then
        statModifier:modifyBaseMultiplier(StatsBonuses.ArmedTurrets, statMultiplier) -- Easiest way to boost damage via turret slots, or use custom damage modifiers if applicable
    elseif targetStat == "Acceleration" then
        statModifier:modifyBaseMultiplier(StatsBonuses.Acceleration, statMultiplier)
    elseif targetStat == "HyperspaceCooldown" then
        statModifier:modifyBaseMultiplier(StatsBonuses.HyperspaceCooldown, statMultiplier)
    end
end
