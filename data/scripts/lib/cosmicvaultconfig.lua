package.path = package.path .. ";data/scripts/lib/?.lua"

local ccm = include("ccm")
local config = ccm and ccm.bind("CosmicVault") or nil

-- namespace CosmicVaultConfig
CosmicVaultConfig = CosmicVaultConfig or {}

if ccm then
    ccm.register("CosmicVault", {
        pages = {
            {
                title = "UI & Keybinds",
                options = {
                    { key = "hotkeyCodex", type = "keybind", title = "Open Cosmic Codex", description = "Hotkey to quickly open the Cosmic Codex tab." },
                    { key = "hotkeyConfigMenu", type = "keybind", title = "Open Config Menu", description = "Hotkey to quickly open the Cosmic Config Menu." },
                }
            },
            {
                title = "Debugging & Framework",
                options = {
                    { key = "debugEnabled", type = "bool", title = "Enable Debug Logs (Master)", description = "Master toggle for all Cosmic mod debug info.", default = true },
                    { key = "debugWar", type = "bool", title = "Debug: Cosmic War", description = "Print debug logs for Cosmic War.", default = true },
                    { key = "debugOverhaul", type = "bool", title = "Debug: Cosmic Overhaul", description = "Print debug logs for Cosmic Overhaul.", default = true },
                    { key = "debugChronicles", type = "bool", title = "Debug: Cosmic Chronicles", description = "Print debug logs for Cosmic Chronicles.", default = true },
                    { key = "debugAscendancy", type = "bool", title = "Debug: Cosmic Ascendancy", description = "Print debug logs for Cosmic Ascendancy.", default = true },
                    { key = "debugStarfall", type = "bool", title = "Debug: Cosmic Starfall", description = "Print debug logs for Cosmic Starfall.", default = true },
                    { key = "debugSymphony", type = "bool", title = "Debug: Cosmic Symphony", description = "Print debug logs for Cosmic Symphony.", default = true },
                    { key = "sectorLoadMetrics", type = "bool", title = "Sector Load Metrics", description = "Print sector generation and load times to console.", default = false },
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
    debugEnabled = true,
    debugWar = true,
    debugOverhaul = true,
    debugChronicles = true,
    debugAscendancy = true,
    debugStarfall = true,
    debugSymphony = true,
    sectorLoadMetrics = false,
    debugPrefix = "[Cosmic]",

    diagnosticsEnabled = true,
    diagnosticsInterval = 300,

    enableFrameworkStrictMode = true,
    enableCompatLayer = true,
}

local function clampNumber(v, minV, maxV, fallback)
    local num = tonumber(v)
    if not num then return fallback end
    if num < minV then return minV end
    if num > maxV then return maxV end
    return num
end

local function readNumber(key, minV, maxV, fallback)
    if not config then return fallback end
    local value = config.get(key)
    if value == nil then return fallback end
    return clampNumber(value, minV, maxV, fallback)
end

local function readBool(key, fallback)
    if not config then return fallback end
    local value = config.get(key)
    if value == nil then return fallback end
    if type(value) == "boolean" then return value end
    if type(value) == "string" then
        local lower = string.lower(value)
        if lower == "true" or lower == "1" then return true end
        if lower == "false" or lower == "0" then return false end
    end
    if type(value) == "number" then
        if value == 1 then return true end
        if value == 0 then return false end
    end
    return fallback
end

local function readString(key, fallback)
    if not config then return fallback end
    local value = config.get(key)
    if value == nil then return fallback end
    if type(value) ~= "string" then return fallback end
    if value == "" then return fallback end
    return value
end

local function build()
    local out = {}

    out.debugEnabled = readBool("debugEnabled", defaults.debugEnabled)
    out.debugWar = readBool("debugWar", defaults.debugWar)
    out.debugOverhaul = readBool("debugOverhaul", defaults.debugOverhaul)
    out.debugChronicles = readBool("debugChronicles", defaults.debugChronicles)
    out.debugAscendancy = readBool("debugAscendancy", defaults.debugAscendancy)
    out.debugStarfall = readBool("debugStarfall", defaults.debugStarfall)
    out.debugSymphony = readBool("debugSymphony", defaults.debugSymphony)
    out.sectorLoadMetrics = readBool("sectorLoadMetrics", defaults.sectorLoadMetrics)
    out.debugPrefix = readString("debugPrefix", defaults.debugPrefix)

    out.diagnosticsEnabled = readBool("diagnosticsEnabled", defaults.diagnosticsEnabled)
    out.diagnosticsInterval = math.floor(readNumber("diagnosticsInterval", 10, 3600, defaults.diagnosticsInterval))

    out.enableFrameworkStrictMode = readBool("enableFrameworkStrictMode", defaults.enableFrameworkStrictMode)
    out.enableCompatLayer = readBool("enableCompatLayer", defaults.enableCompatLayer)

    return out
end

--- Retrieves a configuration value or the entire config table
-- @param key (string, optional) The config key
-- @param default (any, optional) Default value if not found
-- @return (any|table) The config value, or the entire config table if no key is provided
function CosmicVaultConfig.get(key, default)
    local cfg = build()
    if key then
        if cfg[key] ~= nil then
            return cfg[key]
        else
            return default
        end
    end
    return cfg
end

return CosmicVaultConfig
