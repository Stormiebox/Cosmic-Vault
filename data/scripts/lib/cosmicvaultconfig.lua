package.path = package.path .. ";data/scripts/lib/?.lua"

local ccm = include("ccm")
local config = ccm and ccm.bind("CosmicVault") or nil

-- namespace CosmicVaultConfig
CosmicVaultConfig = CosmicVaultConfig or {}

if ccm then
    ccm.register("CosmicVault", {
        pages = {
            {
                title = "Debugging & Framework",
                options = {
                    { key = "debugEnabled", type = "bool", title = "Enable Debug Logs", description = "Prints Cosmic Vault debug info to console.", default = false },
                    { key = "diagnosticsEnabled", type = "bool", title = "Enable Diagnostics", description = "Runs periodic checks on Vault components.", default = true },
                    { key = "diagnosticsInterval", type = "number", title = "Diagnostics Interval (s)", description = "Time between diagnostic checks.", default = 300, min = 10, max = 3600 },
                    { key = "enableFrameworkStrictMode", type = "bool", title = "Strict Mode", description = "Enables strict bounds checking.", default = true },
                    { key = "enableCompatLayer", type = "bool", title = "Compatibility Layer", description = "Improves compatibility with some third party mods.", default = true },
                }
            }
        }
    })
end

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
    local success, value = pcall(config.get, key)
    if not success then return fallback end
    return clampNumber(value, minV, maxV, fallback)
end

local function readBool(key, fallback)
    if not config then return fallback end
    local success, value = pcall(config.get, key)
    if not success then return fallback end
    if type(value) ~= "boolean" then return fallback end
    return value
end

local function readString(key, fallback)
    if not config then return fallback end
    local success, value = pcall(config.get, key)
    if not success then return fallback end
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

--- Retrieves a configuration value
-- @param key (string) The config key
-- @param default (any) Default value if not found
-- @return (any) The config value
function CosmicVaultConfig.get()
    return build()
end

return CosmicVaultConfig
