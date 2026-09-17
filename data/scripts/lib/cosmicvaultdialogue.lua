local Debug = include("cosmicvaultdebug")

-- namespace CosmicVaultDialogue
CosmicVaultDialogue = {}

local MANAGER_PATH = "data/scripts/server/cosmicvaultdialogue_server.lua"
local unpackValues = table.unpack or unpack

local function packValues(...)
    return {n = select("#", ...), ...}
end

local function reportError(message, ...)
    if Debug and Debug.error then Debug.error("CosmicVaultDialogue", message, ...) end
end

local function invokeManager(functionName, ...)
    if not onServer() then return nil, "server_only" end
    local galaxy = Galaxy()
    if not galaxy then return nil, "manager_unavailable" end

    local results = packValues(galaxy:invokeFunction(MANAGER_PATH, functionName, ...))
    if results[1] ~= 0 then
        reportError("Manager call %s failed with invoke status %s.", functionName, tostring(results[1]))
        return nil, "manager_unavailable"
    end
    return unpackValues(results, 2, results.n)
end

function CosmicVaultDialogue.RegisterPublisher(definition)
    return invokeManager("registerPublisher", definition)
end

function CosmicVaultDialogue.RegisterEntries(publisherId, entries)
    return invokeManager("registerEntries", publisherId, entries)
end

function CosmicVaultDialogue.GetEntry(lineId)
    return invokeManager("getEntry", lineId)
end

function CosmicVaultDialogue.Query(category, context, options)
    return invokeManager("query", category, context, options)
end

function CosmicVaultDialogue.GetCatalogSnapshot()
    return invokeManager("getCatalogSnapshot")
end

-- Compatibility wrapper for the original free-form registration shape. The server manager
-- derives a stable legacy line ID, so repeated registration from separate script VMs coalesces.
function CosmicVaultDialogue.registerLine(entry)
    if not onServer() then
        reportError("Dialogue lines can only be registered from the server.")
        return nil, "server_only"
    end
    if type(entry) ~= "table" then
        reportError("Invalid legacy dialogue entry.")
        return nil, "invalid_arguments"
    end
    return invokeManager("registerLegacyEntry", entry)
end

-- Compatibility read shape: return the selected text as the first value. The stable line ID is
-- returned second for callers that want to avoid immediate repetition without breaking v1 users.
function CosmicVaultDialogue.getValidLine(category, currentContext)
    local result, err = CosmicVaultDialogue.Query(category, currentContext or {}, nil)
    if err then return nil, err end
    if type(result) ~= "table" or type(result.entry) ~= "table" then return nil, "not_found" end
    return result.entry.text, result.entry.lineId
end

return CosmicVaultDialogue
