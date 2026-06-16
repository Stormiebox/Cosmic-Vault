package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local CosmicVaultWeather = {}

-- This is a universal API that other mods can require.
-- Example: local cv_weather = include("cosmicvaultweather")
-- cv_weather.triggerStorm(x, y, "IonStorm", 14400) -- 4 hours

function CosmicVaultWeather.triggerStorm(x, y, stormType, duration)
    -- Forward the request to the central server manager
    local server = Server()
    if server then
        server:invokeFunction("server/cosmicvaultweather_server.lua", "createWeather", x, y, stormType, duration)
    end
end

function CosmicVaultWeather.clearStorm(x, y)
    local server = Server()
    if server then
        server:invokeFunction("server/cosmicvaultweather_server.lua", "removeWeather", x, y)
    end
end

-- Synchronous check to see if weather exists at a coordinate.
-- Note: Requires Server context or invokeFunction callback if queried from client.
function CosmicVaultWeather.getWeatherAt(x, y)
    local server = Server()
    if not server then return nil end
    local ok, weather = server:invokeFunction("server/cosmicvaultweather_server.lua", "getWeatherSync", x, y)
    if ok == 0 then
        return weather
    end
    return nil
end

return CosmicVaultWeather
