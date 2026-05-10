package.path = package.path .. ";data/scripts/lib/?.lua"

local mcm = include("mcm")
local config = mcm and mcm.bind("CosmicVault") or nil

-- namespace CosmicVaultConfig
CosmicVaultConfig = CosmicVaultConfig or {}

local defaults = {
    debugEnabled = false,
    debugPrefix = "[Cosmic]",

    diagnosticsEnabled = true,
    diagnosticsInterval = 300,

    enableFrameworkStrictMode = true,
    enableCompatLayer = true,
}

local function clampNumber(v, minV, maxV, fallback)
    if type(v) ~= "number" then return fallback end
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function readNumber(key, minV, maxV, fallback)
    if not config then return fallback end
    local value = config.get(key)
    return clampNumber(value, minV, maxV, fallback)
end

local function readBool(key, fallback)
    if not config then return fallback end
    local value = config.get(key)
    if type(value) ~= "boolean" then return fallback end
    return value
end

local function readString(key, fallback)
    if not config then return fallback end
    local value = config.get(key)
    if type(value) ~= "string" then return fallback end
    if value == "" then return fallback end
    return value
end

local function build()
    local out = {}

    out.debugEnabled = readBool("debugEnabled", defaults.debugEnabled)
    out.debugPrefix = readString("debugPrefix", defaults.debugPrefix)

    out.diagnosticsEnabled = readBool("diagnosticsEnabled", defaults.diagnosticsEnabled)
    out.diagnosticsInterval = math.floor(readNumber("diagnosticsInterval", 10, 3600, defaults.diagnosticsInterval))

    out.enableFrameworkStrictMode = readBool("enableFrameworkStrictMode", defaults.enableFrameworkStrictMode)
    out.enableCompatLayer = readBool("enableCompatLayer", defaults.enableCompatLayer)

    return out
end

function CosmicVaultConfig.get()
    return build()
end
