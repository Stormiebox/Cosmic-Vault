local CosmicVaultWeather = {}

local MANAGER = "data/scripts/server/cosmicvaultweather_server.lua"

local function invoke(functionName, ...)
    if not onServer() then return nil, "client_context" end
    local status, result, errorCode = Galaxy():invokeFunction(MANAGER, functionName, ...)
    if status ~= 0 then return nil, "manager_unavailable" end
    return result, errorCode
end

function CosmicVaultWeather.RegisterWeatherType(definition)
    if type(definition) ~= "table" then return nil, "invalid_arguments" end
    return invoke("registerWeatherType", definition)
end

function CosmicVaultWeather.StartWeather(options)
    if type(options) ~= "table" then return nil, "invalid_arguments" end
    return invoke("startWeather", options)
end

function CosmicVaultWeather.RefreshWeather(conditionId, duration)
    if type(conditionId) ~= "string" or type(duration) ~= "number" then
        return nil, "invalid_arguments"
    end
    return invoke("refreshWeather", conditionId, duration)
end

function CosmicVaultWeather.EndWeather(conditionId, reason)
    if type(conditionId) ~= "string" then return nil, "invalid_arguments" end
    if reason ~= nil and type(reason) ~= "string" then return nil, "invalid_arguments" end
    return invoke("endWeather", conditionId, reason)
end

function CosmicVaultWeather.GetWeather(conditionId)
    if type(conditionId) ~= "string" then return nil, "invalid_arguments" end
    return invoke("getWeather", conditionId)
end

function CosmicVaultWeather.ListWeatherAt(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return nil, "invalid_arguments" end
    return invoke("listWeatherAt", x, y)
end

function CosmicVaultWeather.GetWeatherSnapshot()
    return invoke("getWeatherSnapshot")
end

function CosmicVaultWeather.triggerStorm(x, y, stormType, duration)
    if type(x) ~= "number" or type(y) ~= "number" or type(stormType) ~= "string" then
        return nil, "invalid_arguments"
    end
    if duration ~= nil and type(duration) ~= "number" then return nil, "invalid_arguments" end

    return CosmicVaultWeather.StartWeather({
        sourceId = "legacy-weather:" .. tostring(x) .. ":" .. tostring(y),
        weatherType = stormType,
        x = x,
        y = y,
        duration = duration or -1,
        conflictPolicy = "replace"
    })
end

function CosmicVaultWeather.clearStorm(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return nil, "invalid_arguments" end
    return invoke("clearLegacyWeather", x, y)
end

function CosmicVaultWeather.getWeatherAt(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return nil, "invalid_arguments" end
    return invoke("getLegacyWeatherAt", x, y)
end

return CosmicVaultWeather
