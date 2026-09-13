local CosmicVaultRift = {}

local MANAGER = "data/scripts/server/cosmicvaultriftescalation_server.lua"

local function invoke(functionName, ...)
    if not onServer() then return nil, "client_context" end
    local status, result, errorCode = Galaxy():invokeFunction(MANAGER, functionName, ...)
    if status ~= 0 then return nil, "manager_unavailable" end
    return result, errorCode
end

function CosmicVaultRift.ReportGuardianDestroyed(eventId, evidence)
    if type(eventId) ~= "string" or type(evidence) ~= "table" then
        return nil, "invalid_arguments"
    end
    return invoke("reportGuardianDestroyed", eventId, evidence)
end

function CosmicVaultRift.ReportDeepExtraction(eventId, evidence)
    if type(eventId) ~= "string" or type(evidence) ~= "table" then
        return nil, "invalid_arguments"
    end
    return invoke("reportDeepExtraction", eventId, evidence)
end

function CosmicVaultRift.GetEscalationSnapshot()
    return invoke("getEscalationSnapshot")
end

function CosmicVaultRift.StartRiftHazard(options)
    if type(options) ~= "table" then return nil, "invalid_arguments" end
    local request = {}
    for key, value in pairs(options) do request[key] = value end
    request.weatherType = "RiftInstability"
    local weather = include("cosmicvaultweather")
    return weather.StartWeather(request)
end

function CosmicVaultRift.EndRiftHazard(conditionId, reason)
    if type(conditionId) ~= "string" then return nil, "invalid_arguments" end
    local weather = include("cosmicvaultweather")
    return weather.EndWeather(conditionId, reason or "rift_hazard_ended")
end

return CosmicVaultRift
