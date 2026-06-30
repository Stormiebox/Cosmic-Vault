package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local cv_debuff_type = ""

function initialize(weatherType)
    cv_debuff_type = weatherType or ""
    if onServer() then
        applyDebuffs()
    end
end

function applyDebuffs()
    local entity = Entity()
    entity:removeScriptBonuses() -- Clear any existing bonuses from this script
    
    if cv_debuff_type == "IonStorm" then
        entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, 10.0) -- 1000% slower cooldown
        entity:addBaseMultiplier(StatsBonuses.HyperspaceReach, -1.0) -- -100% reach
        entity:addBaseMultiplier(StatsBonuses.RadarReach, -1.0) -- -100% radar
    elseif cv_debuff_type == "DarkMatterFog" then
        local faction = Faction(entity.factionIndex)
        if not faction or faction.name ~= "The Eclipse" then
            entity:addBaseMultiplier(StatsBonuses.RadarReach, -0.5) -- -50% radar
            entity:addBaseMultiplier(StatsBonuses.HyperspaceReach, -0.5) -- -50% jump
        end
    end
end

function secure()
    return { type = cv_debuff_type }
end

function restore(data)
    cv_debuff_type = data.type
    
    if onServer() then
        if not Sector():hasScript("sector/cv_weather_controller.lua") then
            terminate()
            return
        end
        applyDebuffs()
    end
end
