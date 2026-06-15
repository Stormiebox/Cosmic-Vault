package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local cv_debuff_type = ""

function initialize(weatherType)
    cv_debuff_type = weatherType or ""
    
    if onServer() then
        -- Force a stat recalculation on initialize
        local entity = Entity()
        entity:addMultiplyableFactor(StatsBonuses.RadarReach, 0)
        entity:removeMultiplyableFactor(StatsBonuses.RadarReach)
    end
end

function onBaseMultiplierCalculated(entity, statModifier)
    if cv_debuff_type == "IonStorm" then
        statModifier:modifyBaseMultiplier(StatsBonuses.HyperspaceCooldown, 10.0) -- 1000% slower cooldown
        statModifier:modifyBaseMultiplier(StatsBonuses.HyperspaceReach, 0.0) -- 0 reach
        statModifier:modifyBaseMultiplier(StatsBonuses.RadarReach, 0.0) -- Blind radar
    elseif cv_debuff_type == "DarkMatterFog" then
        local faction = Faction(entity.factionIndex)
        if not faction or faction.name ~= "The Eclipse" then
            statModifier:modifyBaseMultiplier(StatsBonuses.RadarReach, 0.5) -- 50% radar
            statModifier:modifyBaseMultiplier(StatsBonuses.HyperspaceReach, 0.5) -- 50% jump
        end
    end
end

function getUpdateInterval() return 5.0 end

function updateServer(timeStep)
    local sector = Sector()
    -- Self-remove if the sector no longer has weather
    if sector and not sector:hasScript("sector/cv_weather_controller.lua") then
        terminate()
    end
end

function secure()
    return { type = cv_debuff_type }
end

function restore(data)
    cv_debuff_type = data.type
    -- Force stat recalculation on restore
    local entity = Entity()
    entity:addMultiplyableFactor(StatsBonuses.RadarReach, 0)
    entity:removeMultiplyableFactor(StatsBonuses.RadarReach)
end
