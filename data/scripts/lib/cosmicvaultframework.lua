package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultconfig")
include("cosmicvaultdebug")

-- namespace CosmicVaultFramework
CosmicVaultFramework = CosmicVaultFramework or {}

local _registered = _registered or {}

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

function CosmicVaultFramework.registerModule(name, metadata)
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

function CosmicVaultFramework.isRegistered(name)
    return _registered[name] ~= nil
end

function CosmicVaultFramework.getModule(name)
    return _registered[name]
end

function CosmicVaultFramework.getRegisteredModules()
    local out = {}
    for k, v in pairs(_registered) do
        out[k] = v
    end
    return out
end

function CosmicVaultFramework.safeNumber(value, fallback, minV, maxV)
    local n = tonumber(value)
    if not n then return fallback end
    if type(minV) == "number" and n < minV then n = minV end
    if type(maxV) == "number" and n > maxV then n = maxV end
    return n
end

function CosmicVaultFramework.safeBool(value, fallback)
    if type(value) == "boolean" then return value end
    return fallback
end

function CosmicVaultFramework.requireCompat()
    local cfg = _cfg()
    return cfg.enableCompatLayer == true
end

function CosmicVaultFramework.isStrict()
    local cfg = _cfg()
    return cfg.enableFrameworkStrictMode == true
end
