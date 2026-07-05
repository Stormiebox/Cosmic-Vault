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
        player:invokeFunction("data/scripts/player/cv_player_weather_tracker.lua", "syncWeatherMap", CosmicVaultWeatherServer.activeWeathers)
    end
end

function CosmicVaultWeatherServer.getUpdateInterval()
    return 60.0 -- Check expirations once a minute
end

function CosmicVaultWeatherServer.updateServer(timeStep)
    local currentTime = Server().unpausedRuntime or 0
    local changed = false

    for key, weather in pairs(CosmicVaultWeatherServer.activeWeathers) do
        if type(weather) == "table" and type(weather.expiry) == "number" and weather.expiry > 0 and currentTime >= weather.expiry then
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
    if type(duration) == "number" and duration > 0 then
        expiry = (Server().unpausedRuntime or 0) + duration
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
            player:invokeFunction("data/scripts/player/cv_player_weather_tracker.lua", "forceSectorCheck")
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
                player:invokeFunction("data/scripts/player/cv_player_weather_tracker.lua", "forceSectorCleanup")
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
        player:invokeFunction("data/scripts/player/cv_player_weather_tracker.lua", "syncWeatherMap", CosmicVaultWeatherServer.activeWeathers)
    end
end

function CosmicVaultWeatherServer.secure()
    return { activeWeathers = CosmicVaultWeatherServer.activeWeathers }
end

function CosmicVaultWeatherServer.restore(data)
    if type(data) ~= "table" then return end
    CosmicVaultWeatherServer.activeWeathers = type(data.activeWeathers) == "table" and data.activeWeathers or {}
end

function initialize(...)
    if CosmicVaultWeatherServer.initialize then return CosmicVaultWeatherServer.initialize(...) end
end
function onPlayerLogIn(...)
    if CosmicVaultWeatherServer.onPlayerLogIn then return CosmicVaultWeatherServer.onPlayerLogIn(...) end
end
function getUpdateInterval(...)
    if CosmicVaultWeatherServer.getUpdateInterval then return CosmicVaultWeatherServer.getUpdateInterval(...) end
end
function updateServer(...)
    if CosmicVaultWeatherServer.updateServer then return CosmicVaultWeatherServer.updateServer(...) end
end
function secure(...)
    if CosmicVaultWeatherServer.secure then return CosmicVaultWeatherServer.secure(...) end
end
function restore(...)
    if CosmicVaultWeatherServer.restore then return CosmicVaultWeatherServer.restore(...) end
end
