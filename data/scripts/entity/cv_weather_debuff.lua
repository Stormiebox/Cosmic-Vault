
local cv_debuff_type = ""
-- Handles for this instance's own bonuses, so applyDebuffs() can remove exactly its own
-- bonuses on reapply instead of entity:removeScriptBonuses(), which clears EVERY script-added
-- bonus on the entity (including any other Cosmic system's buffs, e.g. a Bastion System or
-- Captain Elite Trait shield bonus) -- same collateral-wipe bug already found and fixed in
-- Cosmic Ascendancy's ascendantaegis.lua and Cosmic Vault's own cosmicbuff.lua. Not persisted
-- across secure()/restore() -- bonus handles are only valid for the current server session,
-- and restore() runs on a fresh script instance whose own local state starts nil anyway.
local bonusKeys = {}

function initialize(weatherType)
    cv_debuff_type = type(weatherType) == "string" and weatherType or ""
    if onServer() then
        applyDebuffs()
    end
end

function applyDebuffs()
    local entity = Entity()
    for _, key in pairs(bonusKeys) do
        entity:removeBonus(key)
    end
    bonusKeys = {}

    if cv_debuff_type == "IonStorm" then
        table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, 10.0)) -- 1000% slower cooldown
        table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.HyperspaceReach, -1.0)) -- -100% reach
        table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.RadarReach, -1.0)) -- -100% radar
    elseif cv_debuff_type == "DarkMatterFog" then
        local faction = Faction(entity.factionIndex)
        local isEclipse = false
        if faction and not faction.isPlayer and not faction.isAlliance then
            if faction.name == "The Eclipse" or faction:getValue("is_eclipse") then
                isEclipse = true
            end
        end

        if not isEclipse then
            table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.RadarReach, -0.5)) -- -50% radar
            table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.HyperspaceReach, -0.5)) -- -50% jump
        end
    end
end

function secure()
    return { type = cv_debuff_type }
end

function restore(data)
    if type(data) ~= "table" then return end
    cv_debuff_type = type(data.type) == "string" and data.type or ""
    
    if onServer() then
        if not Sector():hasScript("data/scripts/sector/cv_weather_controller.lua") then
            terminate()
            return
        end
        applyDebuffs()
    end
end
