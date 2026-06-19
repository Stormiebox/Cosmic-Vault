package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local cv_weather_type = "None"
local cv_weather_time = 0
local cv_weather_duration = 0

function initialize(stormType, duration)
    cv_weather_type = stormType or "IonStorm"
    cv_weather_duration = duration or -1
    cv_weather_time = 0
    
    if onServer() then
        Sector():registerCallback("onEntityEntered", "onEntityEntered")
        -- Initial sweep
        for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
            onEntityEntered(entity.index)
        end
    end
    
    if onClient() then
        if cv_weather_type == "IonStorm" then
            Sector():addScriptOnce("data/scripts/sector/background/lightning.lua")
        elseif cv_weather_type == "DarkMatterFog" then
            -- Attempt to spawn visual fog if Rift DLC particles are available, otherwise standard lightning
            Sector():addScriptOnce("data/scripts/sector/background/lightning.lua")
        end
        -- Attach UI visualizer to player
        Player():addScriptOnce("data/scripts/player/ui/cv_weather_ui.lua", cv_weather_type)
    end
end

function getUpdateInterval()
    return 5.0 -- Efficient 5 second ticks
end

function updateServer(timeStep)
    cv_weather_time = cv_weather_time + timeStep
    if cv_weather_duration > 0 and cv_weather_time >= cv_weather_duration then
        terminate()
        return
    end
    
    -- Handle Solar Flares (Shield Drain)
    if cv_weather_type == "SolarFlare" then
        local entities = {Sector():getEntitiesByType(EntityType.Ship)}
        for _, entity in pairs(entities) do
            local faction = Faction(entity.factionIndex)
            if faction and not faction.isPlayer and not faction.isAlliance then
                if faction.name == "The Eclipse" or faction:getValue("is_eclipse") then
                    goto continue
                end
            end
            
            -- Deal 2% max shield damage per 5-sec tick
            local maxShield = entity.shieldMax or 0
            if maxShield > 0 then
                entity:inflictDamage(maxShield * 0.02, 0, DamageSource.Collision, entity.translationf)
            else
                local maxHull = entity.maxDurability or 0
                entity:inflictDamage(maxHull * 0.005, 0, DamageSource.Collision, entity.translationf)
            end
            
            ::continue::
        end
    end
end

function onEntityEntered(id)
    local entity = Entity(id)
    if not entity or not entity.isShip then return end
    
    -- Check immunity
    local faction = Faction(entity.factionIndex)
    if faction and not faction.isPlayer and not faction.isAlliance then
        if faction.name == "The Eclipse" or faction:getValue("is_eclipse") then
            return
        end
    end
    
    if not entity:hasScript("entity/cv_weather_debuff.lua") then
        entity:addScript("data/scripts/entity/cv_weather_debuff.lua", cv_weather_type)
    end
end

function onRemove()
    if onClient() then
        Player():removeScript("player/ui/cv_weather_ui.lua")
    end
end

function secure()
    return { type = cv_weather_type, time = cv_weather_time, duration = cv_weather_duration }
end

function restore(data)
    cv_weather_type = data.type
    cv_weather_time = data.time
    cv_weather_duration = data.duration
end
