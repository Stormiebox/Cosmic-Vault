package.path = package.path .. ";data/scripts/lib/?.lua"

local targetStat = ""
local statMultiplier = 1.0
local duration = 0
local timeActive = 0
local buffId = ""

-- This is a background entity script that dynamically alters stats and deletes itself.
-- It avoids needing to overwrite the core vanilla ship update loops.

function initialize(statName, multiplier, durationSeconds, id)
    if onServer() then
        targetStat = statName or ""
        statMultiplier = multiplier or 1.0
        duration = durationSeconds or 0
        buffId = id or ""
        timeActive = 0
        applyBuffs()
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

function applyBuffs()
    local entity = Entity()
    entity:removeScriptBonuses()
    
    if targetStat == "Velocity" then
        entity:addBaseMultiplier(StatsBonuses.Velocity, statMultiplier)
    elseif targetStat == "Shield" then
        entity:addBaseMultiplier(StatsBonuses.ShieldDurability, statMultiplier)
    elseif targetStat == "Damage" then
        entity:addBaseMultiplier(StatsBonuses.ArmedTurrets, statMultiplier) -- Easiest way to boost damage via turret slots, or use custom damage modifiers if applicable
    elseif targetStat == "Acceleration" then
        entity:addBaseMultiplier(StatsBonuses.Acceleration, statMultiplier)
    elseif targetStat == "HyperspaceCooldown" then
        entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, statMultiplier)
    elseif targetStat == "HyperspaceReach" then
        entity:addMultiplyableBias(StatsBonuses.HyperspaceReach, statMultiplier)
    elseif targetStat == "ShieldTimeUntilRechargeAfterHit" then
        entity:addBaseMultiplier(StatsBonuses.ShieldTimeUntilRechargeAfterHit, statMultiplier)
    elseif targetStat == "FireRate" then
        entity:addBaseMultiplier(StatsBonuses.FireRate, statMultiplier)
    end
end

function terminateBuffById(targetId)
    if onServer() and buffId == targetId and targetId ~= "" then
        terminate()
    end
end

function refreshBuffById(targetId)
    if onServer() and buffId == targetId and targetId ~= "" then
        timeActive = 0
        return true
    end
    return false
end

function secure()
    return { targetStat = targetStat, statMultiplier = statMultiplier, duration = duration, timeActive = timeActive, buffId = buffId }
end

function restore(data)
    targetStat = data.targetStat
    statMultiplier = data.statMultiplier
    duration = data.duration
    timeActive = data.timeActive
    buffId = data.buffId or ""
    if onServer() then
        applyBuffs()
    end
end
