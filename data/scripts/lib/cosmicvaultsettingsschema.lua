include("cosmicvaultframework")
include("cosmicvaultplayersettings")

--[[
    Cosmic Vault Settings Schema
    Turns "N per-player settings, each hand-plumbed in 2-3 places" into one schema
    array plus generic get/set/reset calls. Storage still goes through
    CosmicVaultPlayerSettings.get/set (its existing "cv_ps_<modId>_<key>" key scheme
    on Player():getValue()/setValue()) -- this is a validation/convenience layer on top,
    not a new storage format.

    IMPORTANT, still-unresolved discrepancy worth knowing before using this module:
    CosmicVaultPlayerSettings.get/set explicitly refuse to run except on the server.
    Cosmic Vault's own WIKI.md (section 10) documents why: in v3.5.0 those functions
    called Player():getValue()/setValue() with no onServer() guard, and "any client-side
    caller (a HUD widget built on this API, for instance) crashed with 'invalid
    userobject of type Player'" -- a real, observed crash, not just theoretical caution.
    Yet Cosmic Overhaul's shipped player/ui/resourcedisplay.lua calls the exact same
    shape of call -- bare Player():getValue(key), client-side, in its own initialize()
    -- with no guard and no reported crash across multiple released versions. The two
    facts don't obviously reconcile (possible explanations: the v3.5.0 crash came from
    a caller passing a server-only Player(callingPlayer)/Player(index) reference into
    client-side code rather than bare Player(), or from a different Avorion version) but
    neither should be resolved by assumption. Since this is new shared API every Cosmic
    mod may end up depending on, this module exposes two distinct, honestly-labeled
    access paths instead of guessing which fact applies:

      - Server-side get/set/resetToDefaults (below): routed through the existing,
        unmodified CosmicVaultPlayerSettings functions, for any server-side code that
        needs a player's setting (a background simulation, an RPC handler, etc).
      - getLocal (below): a CLIENT-side-only read of the local player's own settings,
        following the exact pattern resourcedisplay.lua already ships successfully
        (bare Player():getValue(), no CosmicVaultPlayerSettings involved at all, since
        that library refuses to run client-side regardless of whether the underlying
        engine call would actually be safe there).

    Do not assume one path can stand in for the other without checking which side of
    onClient()/onServer() your own code is running on.
]]

-- namespace CosmicVaultSettingsSchema
CosmicVaultSettingsSchema = CosmicVaultSettingsSchema or {}

local function coerce(value, expectedType, default)
    if expectedType == "bool" then
        if type(value) == "boolean" then return value end
        return default
    elseif expectedType == "number" then
        local n = tonumber(value)
        if n then return n end
        return default
    elseif expectedType == "string" then
        if type(value) == "string" then return value end
        return default
    end
    return value
end

local SchemaHandle = {}
SchemaHandle.__index = SchemaHandle

local function findEntry(schema, key)
    for _, entry in ipairs(schema) do
        if entry.key == key then return entry end
    end
    return nil
end

--- Reads one setting for a player. Server-only (see module note above).
-- @param player (Player)
-- @param key (string) must match a key in the schema this handle was defined with
-- @return (any) the stored value, coerced to the schema's declared type, or the
--     schema default if unset/invalid/unknown key
function SchemaHandle:get(player, key)
    local entry = findEntry(self.schema, key)
    if not entry then return nil end
    local raw = CosmicVaultPlayerSettings.get(player, self.modId, entry.key, entry.default)
    return coerce(raw, entry.type, entry.default)
end

--- Reads every setting in the schema for a player at once. Server-only.
-- @param player (Player)
-- @return (table<string, any>) key -> value, every schema key present with its
--     stored or default value
function SchemaHandle:getAll(player)
    local out = {}
    for _, entry in ipairs(self.schema) do
        out[entry.key] = self:get(player, entry.key)
    end
    return out
end

--- Writes one setting for a player, after validating the key exists in the schema and
-- coercing the value to its declared type. Server-only. This is the validation
-- CosmicOverhaul's own resourcedisplay.lua only partially had (a bare string-prefix
-- check, `string.sub(key,1,6) == "CO_RD_"`, which accepts any key with that prefix
-- rather than one from a known set) -- an unexpected/malformed RPC payload here is
-- rejected outright instead of being written through.
-- @param player (Player)
-- @param key (string)
-- @param value (any)
-- @return (boolean) true if written, false if key is unknown to the schema
function SchemaHandle:set(player, key, value)
    local entry = findEntry(self.schema, key)
    if not entry then
        if CosmicVaultDebug and CosmicVaultDebug.warn then
            CosmicVaultDebug.warn("SettingsSchema", "Rejected unknown key '%s' for mod '%s'", tostring(key), self.modId)
        end
        return false
    end
    local coerced = coerce(value, entry.type, entry.default)
    CosmicVaultPlayerSettings.set(player, self.modId, entry.key, coerced)
    return true
end

--- Resets every schema key back to its declared default for a player. Server-only.
function SchemaHandle:resetToDefaults(player)
    for _, entry in ipairs(self.schema) do
        CosmicVaultPlayerSettings.set(player, self.modId, entry.key, entry.default)
    end
end

--- CLIENT-side read of the local player's own setting -- see the module-level note
-- above for why this does not go through CosmicVaultPlayerSettings.get. Safe to call
-- only for "my own settings on my own machine" (exactly resourcedisplay.lua's existing
-- use case); it is not a substitute for the server-side get() above when the value of
-- a DIFFERENT player is needed.
-- @param key (string)
-- @return (any) the stored value, coerced to the schema's declared type, or default
function SchemaHandle:getLocal(key)
    local entry = findEntry(self.schema, key)
    if not entry then return nil end
    if onServer() then return entry.default end
    local player = Player()
    if not player then return entry.default end
    -- Must read the exact same key set() writes: CosmicVaultPlayerSettings.set() always
    -- prefixes with "cv_ps_<modId>_", so reading the bare entry.key here would silently
    -- read a different, never-written storage slot -- the value the server just saved
    -- would never come back. This duplicates that one-line prefix formula (rather than
    -- calling into CosmicVaultPlayerSettings.get, which refuses to run on the client at
    -- all) so both paths agree on where the value actually lives.
    local storageKey = "cv_ps_" .. self.modId .. "_" .. entry.key
    local raw = player:getValue(storageKey)
    if raw == nil then return entry.default end
    return coerce(raw, entry.type, entry.default)
end

--- Defines a settings schema for a mod and returns a bound handle for get/set/reset.
-- @param modId (string) unique per-mod namespace, passed straight through to
--     CosmicVaultPlayerSettings (e.g. "CosmicOverhaul_ResourceDisplay")
-- @param schema (table) array of { key (string), default (any), type ("bool"|"number"|"string") }.
--     `key` should match any pre-existing storage key your feature already used (e.g.
--     Resource Display's "CO_RD_Enabled") so migrating onto this schema doesn't reset
--     existing players' saved values.
-- @return (table) SchemaHandle -- see get/getAll/set/resetToDefaults/getLocal above
function CosmicVaultSettingsSchema.define(modId, schema)
    return setmetatable({ modId = modId, schema = schema }, SchemaHandle)
end

if CosmicVaultFramework and CosmicVaultFramework.registerModule then
    CosmicVaultFramework.registerModule("CosmicVaultSettingsSchema", {version = "1.0.0"})
end

return CosmicVaultSettingsSchema
