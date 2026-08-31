
local CosmicVaultWeatherDictionary = include("cosmicvaultweatherdictionary")

local cv_weather_type = "None"
local cv_last_weather_type = "None"

function secure()
    return { cv_weather_type = cv_weather_type }
end

function restore(data_in)
    if type(data_in) == "table" and type(data_in.cv_weather_type) == "string" then
        cv_weather_type = data_in.cv_weather_type
    else
        cv_weather_type = "None"
    end
end

function initialize(weatherType)
    if type(weatherType) == "string" then
        cv_weather_type = weatherType
    end
    
    if onClient() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
        updateSectorProblem()
    end
end

function onSectorEntered()
    -- When the player jumps, the old weather is left behind. Clear the local HUD.
    cv_weather_type = "None"
    updateSectorProblem()
end

function setWeatherType(wType)
    if type(wType) == "string" then
        cv_weather_type = wType
        if onClient() then
            updateSectorProblem()
        end
    end
end

-- Avorion has no "addSectorProblem"/"removeSectorProblem" API - it doesn't
-- exist anywhere in the stubs or vanilla source. The real, confirmed
-- mechanism (see vanilla player/ui/badcargoshipproblem.lua) is the ship-level
-- addShipProblem(type, shipUuid, text, icon, color)/removeShipProblem(type,
-- shipUuid) pair, keyed by a constant "type" string per problem slot.
local WEATHER_PROBLEM_TYPE = "CosmicVaultWeather"

function updateSectorProblem()
    local player = Player()
    local craft = player and player.craft
    if not craft then return end

    -- Remove the old problem if it existed
    if cv_last_weather_type ~= "None" then
        removeShipProblem(WEATHER_PROBLEM_TYPE, craft.index)
    end

    -- Add the new problem
    if cv_weather_type ~= "None" then
        local data = CosmicVaultWeatherDictionary.data[cv_weather_type]
        if data then
            local tooltip = data.detailedName .. "\n\n" .. data.description
            addShipProblem(WEATHER_PROBLEM_TYPE, craft.index, tooltip, data.icon, data.color)
        end
    end

    cv_last_weather_type = cv_weather_type
end

function onRemove()
    if cv_weather_type ~= "None" then
        local player = Player()
        local craft = player and player.craft
        if craft then
            removeShipProblem(WEATHER_PROBLEM_TYPE, craft.index)
        end
    end
end
