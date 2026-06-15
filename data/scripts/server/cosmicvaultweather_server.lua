package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local CosmicVaultWeatherServer = {}
CosmicVaultWeatherServer.activeWeathers = {} -- table mapping "x_y" -> {x, y, type, expiry}

function CosmicVaultWeatherServer.initialize()
    local server = Server()
    server:registerCallback("onPlayerLogIn", "onPlayerLogIn")
    
    -- Inject the tracker into all currently online players
    for _, player in pairs({server:getPlayers()}) do
        CosmicVaultWeatherServer.onPlayerLogIn(player.index)
    end
end

function CosmicVaultWeatherServer.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if player then
        player:addScriptOnce("data/scripts/player/cv_player_weather_tracker.lua")
        -- Send the current weather map to the player upon login
        player:invokeFunction("cv_player_weather_tracker.lua", "syncWeatherMap", CosmicVaultWeatherServer.activeWeathers)
    end
end

function CosmicVaultWeatherServer.getUpdateInterval()
    return 60.0 -- Check expirations once a minute
end

function CosmicVaultWeatherServer.updateServer(timeStep)
    local currentTime = os.time()
    local changed = false
    
    for key, weather in pairs(CosmicVaultWeatherServer.activeWeathers) do
        if weather.expiry > 0 and currentTime >= weather.expiry then
            CosmicVaultWeatherServer.activeWeathers[key] = nil
            changed = true
        end
    end
    
    if changed then
        CosmicVaultWeatherServer.broadcastSync()
    end
end

-- API callable from other scripts
function CosmicVaultWeatherServer.createWeather(x, y, stormType, duration)
    local key = tostring(x) .. "_" .. tostring(y)
    local expiry = -1
    if duration and duration > 0 then
        expiry = os.time() + duration
    end
    
    CosmicVaultWeatherServer.activeWeathers[key] = {
        x = x,
        y = y,
        type = stormType,
        expiry = expiry
    }
    
    CosmicVaultWeatherServer.broadcastSync()
    
    -- If a player is currently in this sector, force inject it immediately
    for _, player in pairs({Server():getPlayers()}) do
        local px, py = player:getSectorCoordinates()
        if px == x and py == y then
            player:invokeFunction("cv_player_weather_tracker.lua", "forceSectorCheck")
        end
    end
end

function CosmicVaultWeatherServer.removeWeather(x, y)
    local key = tostring(x) .. "_" .. tostring(y)
    if CosmicVaultWeatherServer.activeWeathers[key] then
        CosmicVaultWeatherServer.activeWeathers[key] = nil
        CosmicVaultWeatherServer.broadcastSync()
        
        -- Clean up players currently in that sector
        for _, player in pairs({Server():getPlayers()}) do
            local px, py = player:getSectorCoordinates()
            if px == x and py == y then
                player:invokeFunction("cv_player_weather_tracker.lua", "forceSectorCleanup")
            end
        end
    end
end

function CosmicVaultWeatherServer.getWeatherSync(x, y)
    local key = tostring(x) .. "_" .. tostring(y)
    return CosmicVaultWeatherServer.activeWeathers[key]
end

-- Sync state
function CosmicVaultWeatherServer.broadcastSync()
    for _, player in pairs({Server():getPlayers()}) do
        player:invokeFunction("cv_player_weather_tracker.lua", "syncWeatherMap", CosmicVaultWeatherServer.activeWeathers)
    end
end

function CosmicVaultWeatherServer.secure()
    return { activeWeathers = CosmicVaultWeatherServer.activeWeathers }
end

function CosmicVaultWeatherServer.restore(data)
    CosmicVaultWeatherServer.activeWeathers = data.activeWeathers or {}
end

return CosmicVaultWeatherServer
