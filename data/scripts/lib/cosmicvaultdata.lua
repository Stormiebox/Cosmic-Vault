
include("cosmicvaultframework")
include("cosmicvaultdebug")
local json = include("dkjson")

-- namespace CosmicVaultData
CosmicVaultData = CosmicVaultData or {}

local function hasActorMethod(actor, methodName)
    if actor == nil then return false end

    local ok, method = pcall(function() return actor[methodName] end)
    return ok and type(method) == "function"
end

local function versionSupported(schemaVersion, supportedVersions)
    if supportedVersions == nil then return true end
    if type(supportedVersions) == "number" then
        return schemaVersion == supportedVersions
    end
    if type(supportedVersions) == "table" then
        return supportedVersions[schemaVersion] == true
    end
    return false
end

--[[
    Cosmic Vault Data & Tagging API
    Allows modders to easily store complex Lua tables onto Entities, and apply tags
    for fast grouping and querying, completely natively without overriding.
]]

--- Sets a persistent data table on an entity
-- @param entity (Entity) The target entity
-- @param key (string) The table key
-- @param data (table) The data to save
function CosmicVaultData.SetTable(entity, key, tbl)
    if not valid(entity) then return false end
    if type(key) ~= "string" then return false end
    if type(tbl) ~= "table" then return false end
    
    local encoded = json.encode(tbl, { indent = false })
    entity:setValue(key, encoded)
    return true
end

--- Retrieves a persistent data table from an entity
-- @param entity (Entity) The target entity
-- @param key (string) The table key
-- @return (table|nil) The data table
function CosmicVaultData.GetTable(entity, key)
    if not valid(entity) or type(key) ~= "string" then return nil end
    local val = entity:getValue(key)
    if type(val) ~= "string" then return nil end
    
    local decoded, pos, err = json.decode(val, 1, nil)
    if err then
        if CosmicVaultDebug then CosmicVaultDebug.error("CosmicVault-Data", "Failed to decode JSON for key %s: %s", key, err) end
        return nil
    end
    return decoded
end

--- Stores a versioned Lua record as a JSON custom value.
-- Avorion custom values only persist primitives, so callers must never pass a
-- record directly to actor:setValue().
-- @param actor (Server|Player|Alliance|Faction|Entity) The persistence owner
-- @param key (string) The custom-value key
-- @param record (table) A record containing a numeric schemaVersion
-- @return (boolean|nil, string|nil) True on success or nil plus an error code
function CosmicVaultData.SetRecord(actor, key, record)
    if not hasActorMethod(actor, "setValue") then return nil, "invalid_actor" end
    if type(key) ~= "string" or key == "" then return nil, "invalid_key" end
    if type(record) ~= "table" then return nil, "invalid_record" end
    if type(record.schemaVersion) ~= "number" then return nil, "missing_schema_version" end

    local encodedOk, encoded = pcall(json.encode, record, {indent = false})
    if not encodedOk or type(encoded) ~= "string" then return nil, "encode_failed" end

    local writeOk = pcall(function() actor:setValue(key, encoded) end)
    if not writeOk then return nil, "write_failed" end
    return true, nil
end

--- Loads and validates a versioned JSON record from an Avorion custom value.
-- @param actor (Server|Player|Alliance|Faction|Entity) The persistence owner
-- @param key (string) The custom-value key
-- @param supportedVersions (number|table|nil) One version or a lookup set
-- @return (table|nil, string|nil) The record or nil plus an error code
function CosmicVaultData.GetRecord(actor, key, supportedVersions)
    if not hasActorMethod(actor, "getValue") then return nil, "invalid_actor" end
    if type(key) ~= "string" or key == "" then return nil, "invalid_key" end

    local readOk, value = pcall(function() return actor:getValue(key) end)
    if not readOk then return nil, "invalid_actor" end
    if value == nil then return nil, "missing" end
    if type(value) ~= "string" or value == "" then return nil, "corrupt" end

    local decodeOk, decoded, _, decodeError = pcall(json.decode, value, 1, nil)
    if not decodeOk or decodeError or type(decoded) ~= "table" then return nil, "corrupt" end
    if type(decoded.schemaVersion) ~= "number" then return nil, "corrupt" end
    if not versionSupported(decoded.schemaVersion, supportedVersions) then
        return nil, "unsupported_version"
    end

    return decoded, nil
end

--- Adds a string tag to an entity
-- @param entity (Entity) The target entity
-- @param tag (string) The tag
function CosmicVaultData.AddTag(entity, tag)
    if not valid(entity) or type(tag) ~= "string" then return false end
    local tags = CosmicVaultData.GetTable(entity, "_cosmic_tags") or {}
    tags[tag] = true
    CosmicVaultData.SetTable(entity, "_cosmic_tags", tags)
    return true
end

--- Removes a string tag from an entity
-- @param entity (Entity) The target entity
-- @param tag (string) The tag
function CosmicVaultData.RemoveTag(entity, tag)
    if not valid(entity) or type(tag) ~= "string" then return false end
    local tags = CosmicVaultData.GetTable(entity, "_cosmic_tags") or {}
    tags[tag] = nil
    CosmicVaultData.SetTable(entity, "_cosmic_tags", tags)
    return true
end

--- Checks if an entity has a specific tag
-- @param entity (Entity) The target entity
-- @param tag (string) The tag
-- @return (boolean) True if tag exists
function CosmicVaultData.HasTag(entity, tag)
    if not valid(entity) or type(tag) ~= "string" then return false end
    local tags = CosmicVaultData.GetTable(entity, "_cosmic_tags") or {}
    return tags[tag] == true
end

--- Retrieves all entities in the sector with a specific tag
-- @param tag (string) The tag
-- @return (table) List of entities
function CosmicVaultData.GetEntitiesByTag(sector, tag)
    if not valid(sector) or type(tag) ~= "string" then return {} end
    local results = {}
    local entities = {sector:getEntities()}
    for _, entity in pairs(entities) do
        if CosmicVaultData.HasTag(entity, tag) then
            table.insert(results, entity)
        end
    end
    return results
end

if CosmicVaultFramework and CosmicVaultFramework.registerModule then
    CosmicVaultFramework.registerModule("CosmicVaultData", {version = "1.0.0"})
end

return CosmicVaultData
