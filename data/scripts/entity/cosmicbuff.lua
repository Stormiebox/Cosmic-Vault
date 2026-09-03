include("callable")

local targetStat = ""
local statMultiplier = 1.0
local duration = 0
local timeActive = 0
local buffId = ""
-- Handle returned by this instance's own addBaseMultiplier call, so applyBuffs() can remove
-- exactly its own bonus on reapply. Not persisted across secure()/restore() -- bonus handles
-- are only valid for the current server session, and restore() runs on a fresh script instance
-- whose own local state starts nil anyway, matching cosmicvaultbuffs.lua's _biasKeys/
-- _baseMultiplierKeys convention.
local bonusKey = nil

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
        sync()
    end
    if onClient() then
        sync()
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
    -- entity:removeScriptBonuses() clears EVERY script-added bonus on the entity, not just
    -- this instance's own -- and entity:addScript() lets multiple cosmicbuff.lua instances
    -- stack on one entity at once (e.g. the Commodore trait's paired Shield + FireRate
    -- buffs), so the sweeping call was silently wiping sibling buffs (and any other Cosmic
    -- system's own bonuses, like Bastion System's) every time a new buff was applied on top.
    -- Same bug pattern already found and fixed in Cosmic Ascendancy's ascendantaegis.lua --
    -- scope removal to this instance's own previously-added bonus instead.
    if bonusKey then
        entity:removeBonus(bonusKey)
        bonusKey = nil
    end

    -- CosmicVaultBuffs.applyBuff() documents statMultiplier as "0.5 for half
    -- speed, 2.0 for double damage" (a scale factor), but addBaseMultiplier
    -- takes an ADDITIVE delta: Final = Base * (1 + delta). Passing the scale
    -- factor directly would turn "half speed" into a +50% speed boost, so it
    -- must be converted to a delta here to match the documented contract.
    local delta = statMultiplier - 1.0

    if targetStat == "Velocity" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.Velocity, delta)
    elseif targetStat == "Shield" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.ShieldDurability, delta)
    elseif targetStat == "ShieldRecharge" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.ShieldRecharge, delta)
    elseif targetStat == "Damage" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.ArmedTurrets, delta) -- Easiest way to boost damage via turret slots, or use custom damage modifiers if applicable
    elseif targetStat == "Acceleration" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.Acceleration, delta)
    elseif targetStat == "HyperspaceCooldown" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, delta)
    elseif targetStat == "HyperspaceReach" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.HyperspaceReach, delta)
    elseif targetStat == "ShieldTimeUntilRechargeAfterHit" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.ShieldTimeUntilRechargeAfterHit, delta)
    elseif targetStat == "FireRate" then
        bonusKey = entity:addBaseMultiplier(StatsBonuses.FireRate, delta)
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

function sync(data)
    if onServer() then
        broadcastInvokeClientFunction("sync", secure())
    else
        if data then
            restore(data)
        else
            invokeServerFunction("sync")
        end
    end
end
callable(nil, "sync")

function updateClient(timeStep)
    timeActive = timeActive + timeStep
    local player = Player()
    if player and player.craftIndex == Entity().index then
        player:invokeFunction("data/scripts/player/ui/cosmicbuff_hud.lua", "registerBuff", buffId, targetStat, duration - timeActive, duration)
    end
end
