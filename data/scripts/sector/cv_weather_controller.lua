-- namespace CosmicVaultLegacyWeatherController
CosmicVaultLegacyWeatherController = {}

local weatherType = "IonStorm"
local duration = -1
local elapsed = 0
local migrated = false

local function remainingDuration()
    if duration == -1 then return -1 end
    return math.max(1, duration - elapsed)
end

local function migrate()
    if not onServer() or migrated then return end
    local sector = Sector()
    if not sector then return end
    local x, y = sector:getCoordinates()
    local weather = include("cosmicvaultweather")
    local record = weather.StartWeather({
        sourceId = "legacy-direct:" .. tostring(x) .. ":" .. tostring(y),
        weatherType = weatherType,
        x = x,
        y = y,
        duration = remainingDuration(),
        conflictPolicy = "replace"
    })
    if record then
        migrated = true
        terminate()
    end
end

function CosmicVaultLegacyWeatherController.initialize(stormType, requestedDuration)
    weatherType = type(stormType) == "string" and stormType or "IonStorm"
    duration = type(requestedDuration) == "number" and requestedDuration or -1
    elapsed = 0
    migrate()
end

function CosmicVaultLegacyWeatherController.getUpdateInterval()
    return 5
end

function CosmicVaultLegacyWeatherController.updateServer(timeStep)
    elapsed = elapsed + timeStep
    if duration > 0 and elapsed >= duration then
        terminate()
        return
    end
    migrate()
end

function CosmicVaultLegacyWeatherController.secure()
    return {type = weatherType, time = elapsed, duration = duration, migrated = migrated}
end

function CosmicVaultLegacyWeatherController.restore(data)
    if type(data) ~= "table" then return end
    weatherType = type(data.type) == "string" and data.type or "IonStorm"
    elapsed = tonumber(data.time) or 0
    duration = tonumber(data.duration) or -1
    migrated = data.migrated == true
    if onServer() and not migrated then migrate() end
end
