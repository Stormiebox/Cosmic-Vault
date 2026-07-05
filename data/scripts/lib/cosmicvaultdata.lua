package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultframework")
include("cosmicvaultdebug")
local json = include("dkjson")

-- namespace CosmicVaultData
CosmicVaultData = CosmicVaultData or {}

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
