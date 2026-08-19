package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultconfig")
include("cosmicvaultdebug")

-- namespace CosmicVaultFramework
CosmicVaultFramework = CosmicVaultFramework or {}

local _registered = CosmicVaultFramework._registered or {}
CosmicVaultFramework._registered = _registered

local function _cfg()
    if CosmicVaultConfig and CosmicVaultConfig.get then
        return CosmicVaultConfig.get()
    end
    return {
        enableFrameworkStrictMode = true,
        enableCompatLayer = true
    }
end

local function _isBlank(v)
    return v == nil or (type(v) == "string" and v == "")
end

--- Registers a module with the framework
-- @param name (string) Module name
-- @param data (table) Module data
function CosmicVaultFramework.registerModule(name, metadata)
    if not name or type(metadata) ~= 'table' then return end
    if _isBlank(name) then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("CosmicVault-Framework", "Refusing to register unnamed module.")
        end
        return false
    end

    if _registered[name] then
        if CosmicVaultDebug and CosmicVaultDebug.warn then
            CosmicVaultDebug.warn("CosmicVault-Framework", "Module already registered: %s", name)
        end
        return true
    end

    _registered[name] = metadata or {}

    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicVault-Framework", "Registered module: %s", name)
    end

    return true
end

--- Checks if a module is registered
-- @param name (string) Module name
-- @return (boolean) True if registered
function CosmicVaultFramework.isRegistered(name)
    return _registered[name] ~= nil
end

--- Gets a registered module's data
-- @param name (string) Module name
-- @return (table|nil) Module data
function CosmicVaultFramework.getModule(name)
    return _registered[name]
end

--- Gets all registered modules
-- @return (table) Registered modules
function CosmicVaultFramework.getRegisteredModules()
    local out = {}
    for k, v in pairs(_registered) do
        out[k] = v
    end
    return out
end

--- Safely parses a number from a value
-- @param val (any) Input value
-- @param default (number) Default value
-- @return (number) Parsed number
function CosmicVaultFramework.safeNumber(value, fallback, minV, maxV)
    local n = tonumber(value)
    if not n then return fallback end
    if type(minV) == "number" and n < minV then n = minV end
    if type(maxV) == "number" and n > maxV then n = maxV end
    return n
end

--- Safely parses a boolean from a value
-- @param val (any) Input value
-- @param default (boolean) Default value
-- @return (boolean) Parsed boolean
function CosmicVaultFramework.safeBool(value, fallback)
    if type(value) == "boolean" then return value end
    return fallback
end

--- Requires another module or mod for compatibility
-- @param name (string) Module or mod name
-- @return (boolean) True if compatible
function CosmicVaultFramework.requireCompat(name)
    if not name then return false end
    local cfg = _cfg()
    return cfg.enableCompatLayer == true
end

--- Checks if strict mode is enabled
-- @return (boolean) True if strict mode
function CosmicVaultFramework.isStrict()
    local cfg = _cfg()
    return cfg.enableFrameworkStrictMode == true
end

--- Validates the type of a variable and logs an error if it mismatches
-- @param value (any) The variable to check
-- @param expectedType (string) The expected Lua type (e.g. "string", "number", "table")
-- @param variableName (string) Optional name of the variable for the error log
-- @return (boolean) True if valid, false if invalid
function CosmicVaultFramework.assertType(value, expectedType, variableName)
    local actualType = type(value)
    if actualType ~= expectedType then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("CosmicVault-Framework", "Type mismatch on variable '%s': expected %s, got %s", variableName or "unknown", expectedType, actualType)
        end
        return false
    end
    return true
end

return CosmicVaultFramework
