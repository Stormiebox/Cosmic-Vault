
include("cosmicvaultconfig")
include("stringutility")

-- namespace CosmicVaultDebug
CosmicVaultDebug = CosmicVaultDebug or {}

local function _cfg()
    if CosmicVaultConfig and CosmicVaultConfig.get then
        return CosmicVaultConfig.get()
    end
    return {
        debugEnabled = true,
        debugWar = true,
        debugOverhaul = true,
        debugChronicles = true,
        debugAscendancy = true,
        debugStarfall = true,
        debugSymphony = true,
        debugPrefix = "[Cosmic]",
    }
end

local function _fmt(msg, ...)
    local n = select("#", ...)
    if n > 0 then
        if type(msg) == "string" and string.find(msg, "%%[sScdiqoxXfgGeE]") then
            local success, res = pcall(string.format, msg, ...)
            if success then return res end
        end
        local t = {tostring(msg)}
        for i = 1, n do
            table.insert(t, tostring(select(i, ...)))
        end
        return table.concat(t, " ")
    end
    return tostring(msg)
end

--- Checks if debug mode is enabled
-- @return (boolean) True if debug mode is active
function CosmicVaultDebug.isEnabled(moduleName)
    local cfg = _cfg()
    if not cfg.debugEnabled then return false end

    if moduleName and type(moduleName) == "string" then
        local lower = string.lower(moduleName)
        if string.find(lower, "war") then
            return cfg.debugWar ~= false
        elseif string.find(lower, "overhaul") then
            return cfg.debugOverhaul ~= false
        elseif string.find(lower, "chronicles") then
            return cfg.debugChronicles ~= false
        elseif string.find(lower, "ascendancy") then
            return cfg.debugAscendancy ~= false
        elseif string.find(lower, "starfall") then
            return cfg.debugStarfall ~= false
        elseif string.find(lower, "symphony") then
            return cfg.debugSymphony ~= false
        end
    end

    return true
end

--- Gets the standardized log prefix
-- @return (string) The prefix
function CosmicVaultDebug.getPrefix(moduleName)
    local cfg = _cfg()
    local base = cfg.debugPrefix or "[Cosmic]"
    if moduleName and moduleName ~= "" then
        return string.format("%s[%s]", base, moduleName)
    end
    return base
end

--- Standard log output
-- @param msg (string) The message
function CosmicVaultDebug.log(moduleName, msg, ...)
    if not CosmicVaultDebug.isEnabled(moduleName) then return end
    print(string.format("%s %s", CosmicVaultDebug.getPrefix(moduleName), _fmt(msg, ...)))
end

--- Info log output
-- @param msg (string) The message
function CosmicVaultDebug.info(moduleName, msg, ...)
    if not CosmicVaultDebug.isEnabled(moduleName) then return end
    print(string.format("%s[INFO] %s", CosmicVaultDebug.getPrefix(moduleName), _fmt(msg, ...)))
end

--- Warning log output
-- @param msg (string) The message
function CosmicVaultDebug.warn(moduleName, msg, ...)
    if not CosmicVaultDebug.isEnabled(moduleName) then return end
    print(string.format("%s[WARN] %s", CosmicVaultDebug.getPrefix(moduleName), _fmt(msg, ...)))
end

--- Error log output
-- @param msg (string) The message
function CosmicVaultDebug.error(moduleName, msg, ...)
    if not msg then return end
    -- Always print errors regardless of debug toggle.
    print(string.format("%s[ERROR] %s", CosmicVaultDebug.getPrefix(moduleName), _fmt(msg, ...)))
end

return CosmicVaultDebug
