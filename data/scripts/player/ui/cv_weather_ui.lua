package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

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

function updateSectorProblem()
    -- Remove the old problem if it existed
    if cv_last_weather_type ~= "None" then
        local oldData = CosmicVaultWeatherDictionary.data[cv_last_weather_type]
        if oldData then
            removeSectorProblem(oldData.name)
        end
    end
    
    -- Add the new problem
    if cv_weather_type ~= "None" then
        local data = CosmicVaultWeatherDictionary.data[cv_weather_type]
        if data then
            local tooltip = data.detailedName .. "\n\n" .. data.description
            addSectorProblem(data.name, tooltip, data.icon, data.color)
        end
    end
    
    cv_last_weather_type = cv_weather_type
end

function onRemove()
    if cv_weather_type ~= "None" then
        local data = CosmicVaultWeatherDictionary.data[cv_weather_type]
        if data then
            removeSectorProblem(data.name)
        end
    end
end
