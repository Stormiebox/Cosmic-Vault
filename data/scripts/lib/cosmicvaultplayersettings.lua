package.path = package.path .. ";data/scripts/lib/?.lua"
include("cosmicvaultdebug")

-- namespace CosmicVaultPlayerSettings
-- API for storing and retrieving player-specific settings using the performant and persistent
-- Player():getValue() and setValue() system, avoiding direct file I/O.
CosmicVaultPlayerSettings = {}

local function getStorageKey(modId, key)
    if not modId or type(modId) ~= "string" or modId == "" then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("PlayerSettings", "Mod ID is required and must be a string to get/set a player setting.")
        end
        return nil
    end
    if not key or type(key) ~= "string" or key == "" then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("PlayerSettings", "Key is required and must be a string to get/set a player setting.")
        end
        return nil
    end
    return "cv_ps_" .. modId .. "_" .. key
end

--[[
    Retrieves a player-specific setting.
    @param player (Player): The player object.
    @param modId (string): The unique ID of the calling mod for namespacing.
    @param key (string): The setting key.
    @param fallback (any): The default value to return if the setting is not found.
    @return (any): The stored value or the fallback.
]]
--- Gets a player setting
-- @param player (Player) The player
-- @param key (string) The setting key
-- @param default (any) Default value
-- @return (any) The setting value
function CosmicVaultPlayerSettings.get(player, modId, key, fallback)
    if not valid(player) then return fallback end

    local storageKey = getStorageKey(modId, key)
    if not storageKey then return fallback end

    local value = player:getValue(storageKey)
    if value == nil then
        return fallback
    end

    return value
end

--[[
    Stores a player-specific setting.
    @param player (Player): The player object.
    @param modId (string): The unique ID of the calling mod for namespacing.
    @param key (string): The setting key.
    @param value (any): The value to store. Must be a type supported by player:setValue().
]]
--- Sets a player setting
-- @param player (Player) The player
-- @param key (string) The setting key
-- @param val (any) The value to set
function CosmicVaultPlayerSettings.set(player, modId, key, value)
    if not valid(player) then return end

    local storageKey = getStorageKey(modId, key)
    if not storageKey then return end

    player:setValue(storageKey, value)
end

return CosmicVaultPlayerSettings