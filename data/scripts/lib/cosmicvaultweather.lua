
local CosmicVaultWeather = {}

-- This is a universal API that other mods can require.
-- Example: local cv_weather = include("cosmicvaultweather")
-- cv_weather.triggerStorm(x, y, "IonStorm", 14400) -- 4 hours

function CosmicVaultWeather.triggerStorm(x, y, stormType, duration)
    if type(x) ~= "number" or type(y) ~= "number" or type(stormType) ~= "string" then return end
    if duration and type(duration) ~= "number" then return end
    if not onServer() then return end
    -- Forward the request to the central server manager
    Galaxy():invokeFunction("server/cosmicvaultweather_server.lua", "createWeather", x, y, stormType, duration)
end

function CosmicVaultWeather.clearStorm(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return end
    if not onServer() then return end
    Galaxy():invokeFunction("server/cosmicvaultweather_server.lua", "removeWeather", x, y)
end

-- Synchronous check to see if weather exists at a coordinate.
-- Note: Requires Server context or invokeFunction callback if queried from client.
function CosmicVaultWeather.getWeatherAt(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    if not onServer() then return nil end
    local ok, weather = Galaxy():invokeFunction("server/cosmicvaultweather_server.lua", "getWeatherSync", x, y)
    if ok == 0 then
        return weather
    end
    return nil
end

return CosmicVaultWeather
