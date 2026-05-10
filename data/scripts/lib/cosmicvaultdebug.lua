package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultconfig")
include("stringutility")

-- namespace CosmicVaultDebug
CosmicVaultDebug = CosmicVaultDebug or {}

local function _cfg()
    if CosmicVaultConfig and CosmicVaultConfig.get then
        return CosmicVaultConfig.get()
    end
    return {
        debugEnabled = false,
        debugPrefix = "[Cosmic]",
    }
end

local function _fmt(msg, ...)
    if select("#", ...) > 0 then
        return string.format(msg, ...)
    end
    return tostring(msg)
end

function CosmicVaultDebug.isEnabled()
    local cfg = _cfg()
    return cfg.debugEnabled == true
end

function CosmicVaultDebug.getPrefix(moduleName)
    local cfg = _cfg()
    local base = cfg.debugPrefix or "[Cosmic]"
    if moduleName and moduleName ~= "" then
        return string.format("%s[%s]", base, moduleName)
    end
    return base
end

function CosmicVaultDebug.log(moduleName, msg, ...)
    if not CosmicVaultDebug.isEnabled() then return end
    print("%s %s", CosmicVaultDebug.getPrefix(moduleName), _fmt(msg, ...))
end

function CosmicVaultDebug.info(moduleName, msg, ...)
    if not CosmicVaultDebug.isEnabled() then return end
    print("%s[INFO] %s", CosmicVaultDebug.getPrefix(moduleName), _fmt(msg, ...))
end

function CosmicVaultDebug.warn(moduleName, msg, ...)
    if not CosmicVaultDebug.isEnabled() then return end
    print("%s[WARN] %s", CosmicVaultDebug.getPrefix(moduleName), _fmt(msg, ...))
end

function CosmicVaultDebug.error(moduleName, msg, ...)
    -- Always print errors regardless of debug toggle.
    print("%s[ERROR] %s", CosmicVaultDebug.getPrefix(moduleName), _fmt(msg, ...))
end
