package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local cv_weather_type = "None"
local cv_weather_time = 0
local cv_weather_duration = 0

function initialize(stormType, duration)
    cv_weather_type = type(stormType) == "string" and stormType or "IonStorm"
    cv_weather_duration = type(duration) == "number" and duration or -1
    cv_weather_time = 0
    
    if onServer() then
        Sector():registerCallback("onEntityEntered", "onEntityEntered")
        Sector():registerCallback("onEntityLeft", "onEntityLeft")
        -- Initial sweep
        for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
            onEntityEntered(entity.index)
        end
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
            if not valid(entity) then goto continue end
            local faction = Faction(entity.factionIndex)
            if faction and not faction.isPlayer and not faction.isAlliance then
                if faction.name == "The Eclipse" or faction:getValue("is_eclipse") then
                    goto continue
                end
            end
            
            -- Deal 2% max shield damage per 5-sec tick
            local maxShield = entity.shieldMax or 0
            if maxShield > 0 then
                entity:inflictDamage(maxShield * 0.02, 1, DamageType.Energy, entity.translationf, entity.id)
            else
                local maxHull = entity.maxDurability or 0
                entity:inflictDamage(maxHull * 0.005, 1, DamageType.Physical, entity.translationf, entity.id)
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
    
    local scriptPath = "data/scripts/entity/cv_weather_debuff.lua"
    if not entity:hasScript(scriptPath) then
        entity:addScriptOnce(scriptPath, cv_weather_type)
    end

    -- Send chat warning for players
    if faction and faction.isPlayer then
        local player = Player(faction.index)
        if player then
            if cv_weather_type == "IonStorm" then
                player:sendChatMessage("Weather Alert", 2, "WARNING: Ion Storm detected! Radar and hyperspace systems impaired.")
            elseif cv_weather_type == "SolarFlare" then
                player:sendChatMessage("Weather Alert", 2, "WARNING: Solar Flare detected! Shields are actively draining.")
            elseif cv_weather_type == "DarkMatterFog" then
                player:sendChatMessage("Weather Alert", 2, "WARNING: Dark Matter Fog detected! Sensors severely impaired.")
            end
        end
    end
end

function onEntityLeft(id)
    local entity = Entity(id)
    if not valid(entity) or not entity.isShip then return end
    
    local scriptPath = "data/scripts/entity/cv_weather_debuff.lua"
    if entity:hasScript(scriptPath) then
        entity:removeScript(scriptPath)
    end
end

function onRemove()
    if onClient() then
        Player():removeScript("data/scripts/player/ui/cv_weather_ui.lua")
    end
    if onServer() then
        for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
            entity:removeScript("data/scripts/entity/cv_weather_debuff.lua")
        end
    end
end

function secure()
    return { type = cv_weather_type, time = cv_weather_time, duration = cv_weather_duration }
end

function restore(data)
    if type(data) ~= "table" then return end
    cv_weather_type = data.type or "None"
    cv_weather_time = data.time or 0
    cv_weather_duration = data.duration or -1
    
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
