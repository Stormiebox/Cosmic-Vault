-- namespace CosmicVaultWeatherServer
CosmicVaultWeatherServer = {}

local CosmicVaultData = include("cosmicvaultdata")
local WeatherDictionary = include("cosmicvaultweatherdictionary")
local CosmicVaultNewsAdapter = include("cosmicvaultnewsadapter")

local RECORD_KEY = "cv_weather_v2"
local SCHEMA_VERSION = 2
local TRACKER = "data/scripts/player/cv_player_weather_tracker.lua"
local MAX_ATTEMPTS = 5
local TOMBSTONE_LIFETIME = 7 * 24 * 60 * 60
local TOMBSTONE_CAP = 2048
local REPAIR_FINDING_CAP = 256

local state
local storageError
local legacyRestore
local legacyEvidence

local function now()
    local server = Server()
    return server and server.unpausedRuntime or 0
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return copy
end

local function deepEqual(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not deepEqual(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function validCoordinate(value)
    return type(value) == "number" and value == math.floor(value)
end

local function coordinateKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function newState()
    return {
        schemaVersion = SCHEMA_VERSION,
        revision = 0,
        migratedAt = 0,
        migrationProvenance = {},
        typeDefinitions = WeatherDictionary.getDefinitions(),
        conditions = {},
        tombstones = {},
        repairFindings = {}
    }
end

local function validateState(record)
    if type(record) ~= "table" or record.schemaVersion ~= SCHEMA_VERSION then return false end
    if type(record.revision) ~= "number" then return false end
    if type(record.typeDefinitions) ~= "table" then return false end
    if type(record.conditions) ~= "table" or type(record.tombstones) ~= "table" then return false end
    if type(record.migrationProvenance) ~= "table" then return false end
    if record.repairFindings ~= nil and type(record.repairFindings) ~= "table" then return false end

    for typeName, definition in pairs(record.typeDefinitions) do
        if type(typeName) ~= "string" or type(definition) ~= "table"
                or definition.type ~= typeName or type(definition.category) ~= "string"
                or type(definition.stackingGroup) ~= "string"
                or type(definition.icon) ~= "string" or type(definition.name) ~= "string"
                or type(definition.detailedName) ~= "string"
                or type(definition.description) ~= "string"
                or type(definition.chatWarning) ~= "string"
                or type(definition.presentationProfile) ~= "string"
                or type(definition.mechanicsProfile) ~= "string"
                or type(definition.color) ~= "table"
                or type(definition.color.r) ~= "number"
                or type(definition.color.g) ~= "number"
                or type(definition.color.b) ~= "number" then
            return false
        end
    end

    local activeStates = {active = true, retryable = true, repair_required = true}
    for conditionId, condition in pairs(record.conditions) do
        local definition = type(condition) == "table"
            and record.typeDefinitions[condition.weatherType] or nil
        if type(conditionId) ~= "string" or type(condition) ~= "table"
                or condition.schemaVersion ~= SCHEMA_VERSION
                or condition.conditionId ~= conditionId
                or type(condition.revision) ~= "number"
                or type(condition.sourceId) ~= "string" or not definition
                or condition.category ~= definition.category
                or condition.stackingGroup ~= definition.stackingGroup
                or not validCoordinate(condition.x) or not validCoordinate(condition.y)
                or not activeStates[condition.state]
                or type(condition.createdAt) ~= "number"
                or type(condition.updatedAt) ~= "number"
                or type(condition.expiresAt) ~= "number"
                or type(condition.attempts) ~= "number" then
            return false
        end
    end

    for conditionId, tombstone in pairs(record.tombstones) do
        if type(conditionId) ~= "string" or type(tombstone) ~= "table"
                or tombstone.conditionId ~= conditionId
                or (tombstone.state ~= "abandoned" and tombstone.state ~= "expired"
                    and tombstone.state ~= "failed_permanent")
                or type(tombstone.completedAt) ~= "number" then
            return false
        end
    end
    for findingId, finding in pairs(record.repairFindings or {}) do
        if type(findingId) ~= "string" or type(finding) ~= "table"
                or finding.findingId ~= findingId
                or finding.state ~= "repair_required"
                or type(finding.kind) ~= "string"
                or type(finding.detectedAt) ~= "number" then
            return false
        end
    end
    return true
end

local function ensureLoaded()
    if state then return true, nil end
    if storageError then return nil, storageError end

    local loaded, err = CosmicVaultData.GetRecord(Server(), RECORD_KEY, SCHEMA_VERSION)
    if not loaded and err == "missing" then
        state = newState()
        return true, nil
    end
    if not loaded then
        storageError = err
        return nil, err
    end
    if not validateState(loaded) then
        storageError = "corrupt"
        return nil, storageError
    end

    state = loaded
    state.repairFindings = state.repairFindings or {}
    for typeName, definition in pairs(WeatherDictionary.getDefinitions()) do
        if state.typeDefinitions[typeName] == nil then state.typeDefinitions[typeName] = definition end
    end
    return true, nil
end

local function persist(working)
    working.revision = (state and state.revision or working.revision or 0) + 1
    local ok, err = CosmicVaultData.SetRecord(Server(), RECORD_KEY, working)
    if not ok then
        working.lastError = tostring(err or "write_failed")
        return nil, "persistence_failure"
    end
    state = working
    return true, nil
end

local function weatherNewsEventId(condition)
    return CosmicVaultNewsAdapter.StableId("hazard", condition.conditionId)
end

local function publishWeatherCondition(condition)
    if type(condition) ~= "table" then return nil, "invalid_arguments" end
    local definition = state and state.typeDefinitions[condition.weatherType]
        or WeatherDictionary.getDefinition(condition.weatherType)
    if not definition then return nil, "unknown_type" end
    local eventId, idError = weatherNewsEventId(condition)
    if not eventId then return nil, idError end
    local isRift = condition.category == "rift"
    local active = condition.state == "active" or condition.state == "retryable"
        or condition.state == "repair_required"
    local severity = isRift and "critical" or "warning"
    local content
    if active then
        content = tostring(definition.detailedName) .. " is active in sector ("
            .. tostring(condition.x) .. ", " .. tostring(condition.y) .. "). "
            .. tostring(definition.description)
    else
        content = tostring(definition.detailedName) .. " in sector ("
            .. tostring(condition.x) .. ", " .. tostring(condition.y) .. ") has ended."
    end
    local article, publishError = CosmicVaultNewsAdapter.Upsert({
        eventId = eventId,
        threadId = eventId,
        eventType = isRift and "rift.hazard.lifecycle" or "weather.lifecycle",
        topic = isRift and "rift" or "weather",
        category = isRift and "Rift" or "Weather",
        severity = severity,
        breaking = isRift,
        title = tostring(definition.detailedName),
        content = content,
        author = "Cosmic Vault",
        location = {x = condition.x, y = condition.y, radius = 12},
        audience = {mode = "region"},
        lead = {kind = "location", x = condition.x, y = condition.y,
            expiresAt = condition.expiresAt ~= -1 and condition.expiresAt or nil},
        expiresAt = active and condition.expiresAt ~= -1 and condition.expiresAt or nil,
        provenance = {
            recordType = "cv_weather_v2",
            conditionId = tostring(condition.conditionId),
            sourceId = tostring(condition.sourceId),
            sourceRevision = condition.revision or 0,
            sourceState = tostring(condition.state),
            weatherType = tostring(condition.weatherType),
        },
    })
    if publishError then return nil, publishError end
    if not active then
        return CosmicVaultNewsAdapter.Resolve(eventId,
            "Hazard " .. tostring(condition.state) .. ": " .. tostring(condition.reason or "ended"),
            condition.state == "expired" and "expired" or "resolved")
    end
    return article, nil
end

local function serializable(value, seen)
    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "number" or valueType == "string" then
        return valueType ~= "number" or (value == value and value ~= math.huge and value ~= -math.huge)
    end
    if valueType ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for key, item in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then return false end
        if not serializable(item, seen) then return false end
    end
    seen[value] = nil
    return true
end

local function validateDefinition(definition)
    if type(definition) ~= "table" or not serializable(definition) then return nil, "invalid_arguments" end
    local requiredStrings = {
        "type", "category", "stackingGroup", "icon", "name", "detailedName",
        "description", "chatWarning", "presentationProfile", "mechanicsProfile"
    }
    for _, key in ipairs(requiredStrings) do
        if type(definition[key]) ~= "string" or definition[key] == "" then
            return nil, "invalid_arguments"
        end
    end
    if string.match(definition.type, "^[%w_%-]+$") == nil then return nil, "invalid_arguments" end
    if type(definition.color) ~= "table"
            or type(definition.color.r) ~= "number"
            or type(definition.color.g) ~= "number"
            or type(definition.color.b) ~= "number" then
        return nil, "invalid_arguments"
    end
    for _, channel in ipairs({definition.color.r, definition.color.g, definition.color.b}) do
        if channel < 0 or channel > 1 then return nil, "invalid_arguments" end
    end
    if definition.mechanicsProfile ~= "presentation_only" then return nil, "invalid_arguments" end
    return deepCopy(definition), nil
end

local function calculateExpiry(duration, currentTime)
    if duration == -1 then return -1 end
    if type(duration) ~= "number" or duration <= 0 then return nil end
    return currentTime + duration
end

local function isActive(condition, currentTime)
    if type(condition) ~= "table"
            or (condition.state ~= "active" and condition.state ~= "retryable") then
        return false
    end
    return condition.expiresAt == -1
        or (type(condition.expiresAt) == "number" and condition.expiresAt > currentTime)
end

local function sortedConditionsAt(record, x, y, currentTime)
    local result = {}
    for _, condition in pairs(record.conditions) do
        if condition.x == x and condition.y == y and isActive(condition, currentTime) then
            table.insert(result, deepCopy(condition))
        end
    end
    table.sort(result, function(left, right) return left.conditionId < right.conditionId end)
    return result
end

local function deriveConditionId(options)
    return options.weatherType .. ":" .. options.sourceId .. ":" .. coordinateKey(options.x, options.y)
end

local function retireCondition(working, conditionId, terminalState, reason, currentTime)
    local condition = working.conditions[conditionId]
    if not condition then return end
    condition = deepCopy(condition)
    condition.state = "resolving"
    condition.revision = (condition.revision or 0) + 1
    condition.updatedAt = currentTime
    working.conditions[conditionId] = nil
    condition.state = terminalState
    condition.reason = reason
    condition.completedAt = currentTime
    condition.updatedAt = currentTime
    working.tombstones[conditionId] = condition
end

local function pruneTombstones(working, currentTime)
    local retained = {}
    for id, tombstone in pairs(working.tombstones) do
        if type(tombstone.completedAt) ~= "number" or currentTime - tombstone.completedAt < TOMBSTONE_LIFETIME then
            table.insert(retained, {id = id, record = tombstone})
        end
    end
    table.sort(retained, function(left, right)
        return (left.record.completedAt or 0) > (right.record.completedAt or 0)
    end)
    working.tombstones = {}
    for index = 1, math.min(#retained, TOMBSTONE_CAP) do
        local item = retained[index]
        working.tombstones[item.id] = item.record
    end
end

local function recordTypeConflict(working, existing, conflicting)
    working.repairFindings = working.repairFindings or {}
    local findingId = "weather_type_conflict:" .. conflicting.type
    working.repairFindings[findingId] = {
        findingId = findingId,
        kind = "type_conflict",
        state = "repair_required",
        weatherType = conflicting.type,
        detectedAt = now(),
        existingDefinition = deepCopy(existing),
        conflictingDefinition = deepCopy(conflicting)
    }

    local retained = {}
    for id, finding in pairs(working.repairFindings) do
        table.insert(retained, {id = id, finding = finding})
    end
    table.sort(retained, function(left, right)
        return (left.finding.detectedAt or 0) > (right.finding.detectedAt or 0)
    end)
    working.repairFindings = {}
    for index = 1, math.min(#retained, REPAIR_FINDING_CAP) do
        local item = retained[index]
        working.repairFindings[item.id] = item.finding
    end
end

local function notifyCoordinate(x, y, reason)
    for _, player in pairs({Server():getOnlinePlayers()}) do
        local px, py = player:getSectorCoordinates()
        if px == x and py == y then
            player:addScriptOnce(TRACKER)
            if player:hasScript(TRACKER) then
                player:invokeFunction(TRACKER, "weatherChanged", x, y, state.revision, reason)
            end
        end
    end
end

local function migrateLegacy()
    if not legacyRestore or type(legacyRestore.activeWeathers) ~= "table" then return true, nil end
    local loaded, err = ensureLoaded()
    if not loaded then return nil, err end
    if state.migrationProvenance.legacySecure then return true, nil end

    local working = deepCopy(state)
    local currentTime = now()
    local findings = {}
    for legacyKey, legacy in pairs(legacyRestore.activeWeathers) do
        if type(legacy) ~= "table" or not validCoordinate(legacy.x) or not validCoordinate(legacy.y)
                or type(legacy.type) ~= "string" then
            table.insert(findings, {legacyKey = tostring(legacyKey), error = "malformed_legacy_weather"})
        elseif tostring(legacyKey) ~= tostring(legacy.x) .. "_" .. tostring(legacy.y) then
            table.insert(findings, {legacyKey = tostring(legacyKey), error = "coordinate_mismatch"})
        elseif not working.typeDefinitions[legacy.type] then
            table.insert(findings, {legacyKey = tostring(legacyKey), error = "unknown_type"})
        else
            local sourceId = "legacy-weather:" .. coordinateKey(legacy.x, legacy.y)
            local conditionId = legacy.type .. ":" .. sourceId .. ":" .. coordinateKey(legacy.x, legacy.y)
            local definition = working.typeDefinitions[legacy.type]
            local expiry = tonumber(legacy.expiry) or -1
            if expiry == -1 or expiry > currentTime then
                working.conditions[conditionId] = {
                    schemaVersion = SCHEMA_VERSION,
                    revision = 1,
                    conditionId = conditionId,
                    sourceId = sourceId,
                    weatherType = legacy.type,
                    category = definition.category,
                    stackingGroup = definition.stackingGroup,
                    x = legacy.x,
                    y = legacy.y,
                    state = "active",
                    createdAt = currentTime,
                    updatedAt = currentTime,
                    expiresAt = expiry,
                    attempts = 0,
                    materializedRevision = 0
                }
            end
        end
    end

    working.migratedAt = currentTime
    working.migrationProvenance.legacySecure = {migratedAt = currentTime, findings = findings}
    local saved, saveError = persist(working)
    if not saved then return nil, saveError end
    return true, nil
end

function CosmicVaultWeatherServer.initialize()
    if not onServer() then return end
    ensureLoaded()
    migrateLegacy()

    local server = Server()
    server:registerCallback("onPlayerLogIn", "onPlayerLogIn")
    for _, player in pairs({server:getOnlinePlayers()}) do
        CosmicVaultWeatherServer.onPlayerLogIn(player.index)
    end
end

function CosmicVaultWeatherServer.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if not player then return end
    player:addScriptOnce(TRACKER)
end

function CosmicVaultWeatherServer.registerWeatherType(definition)
    local available, err = ensureLoaded()
    if not available then return nil, err end
    local checked, validationError = validateDefinition(definition)
    if not checked then return nil, validationError end

    local existing = state.typeDefinitions[checked.type]
    if existing then
        if deepEqual(existing, checked) then return deepCopy(existing), nil end
        local working = deepCopy(state)
        recordTypeConflict(working, existing, checked)
        local saved, saveError = persist(working)
        if not saved then return nil, saveError end
        return nil, "type_conflict"
    end

    local working = deepCopy(state)
    working.typeDefinitions[checked.type] = checked
    local saved, saveError = persist(working)
    if not saved then return nil, saveError end
    return deepCopy(checked), nil
end

function CosmicVaultWeatherServer.startWeather(options)
    local available, err = ensureLoaded()
    if not available then return nil, err end
    if type(options) ~= "table" or type(options.sourceId) ~= "string" or options.sourceId == ""
            or type(options.weatherType) ~= "string" or not validCoordinate(options.x)
            or not validCoordinate(options.y) then
        return nil, "invalid_arguments"
    end

    local definition = state.typeDefinitions[options.weatherType]
    if not definition then return nil, "unknown_type" end
    local policy = options.conflictPolicy or "reject"
    if policy ~= "reject" and policy ~= "replace" then return nil, "invalid_arguments" end
    local currentTime = now()
    local expiry = calculateExpiry(options.duration == nil and -1 or options.duration, currentTime)
    if not expiry then return nil, "invalid_arguments" end
    local conditionId = options.conditionId or deriveConditionId(options)
    if type(conditionId) ~= "string" or conditionId == "" then return nil, "invalid_arguments" end

    local existing = state.conditions[conditionId]
    if existing then
        if existing.sourceId ~= options.sourceId or existing.weatherType ~= options.weatherType
                or existing.x ~= options.x or existing.y ~= options.y then
            return nil, "stacking_conflict"
        end
        return CosmicVaultWeatherServer.refreshWeather(conditionId, options.duration == nil and -1 or options.duration)
    end

    local working = deepCopy(state)
    for otherId, other in pairs(working.conditions) do
        if other.x == options.x and other.y == options.y and other.stackingGroup == definition.stackingGroup
                and isActive(other, currentTime) then
            if policy ~= "replace" then return nil, "stacking_conflict" end
            retireCondition(working, otherId, "abandoned", "replaced", currentTime)
        end
    end

    local record = {
        schemaVersion = SCHEMA_VERSION,
        revision = 1,
        conditionId = conditionId,
        sourceId = options.sourceId,
        weatherType = options.weatherType,
        category = definition.category,
        stackingGroup = definition.stackingGroup,
        x = options.x,
        y = options.y,
        state = "active",
        createdAt = currentTime,
        updatedAt = currentTime,
        expiresAt = expiry,
        attempts = 0,
        materializedRevision = 0
    }
    working.conditions[conditionId] = record
    pruneTombstones(working, currentTime)
    local saved, saveError = persist(working)
    if not saved then return nil, saveError end
    for _, retired in pairs(working.tombstones) do
        if retired.completedAt == currentTime then publishWeatherCondition(retired) end
    end
    publishWeatherCondition(record)
    notifyCoordinate(record.x, record.y, "started")
    return deepCopy(record), nil
end

function CosmicVaultWeatherServer.refreshWeather(conditionId, duration)
    local available, err = ensureLoaded()
    if not available then return nil, err end
    if type(conditionId) ~= "string" then return nil, "invalid_arguments" end
    local record = state.conditions[conditionId]
    if not record then return nil, "missing" end
    local currentTime = now()
    local expiry = calculateExpiry(duration, currentTime)
    if not expiry then return nil, "invalid_arguments" end

    local working = deepCopy(state)
    record = working.conditions[conditionId]
    record.revision = (record.revision or 0) + 1
    record.updatedAt = currentTime
    record.expiresAt = expiry
    record.lastError = nil
    record.repairRequired = nil
    local saved, saveError = persist(working)
    if not saved then return nil, saveError end
    publishWeatherCondition(record)
    notifyCoordinate(record.x, record.y, "refreshed")
    return deepCopy(record), nil
end

function CosmicVaultWeatherServer.endWeather(conditionId, reason)
    local available, err = ensureLoaded()
    if not available then return nil, err end
    if type(conditionId) ~= "string" then return nil, "invalid_arguments" end
    local record = state.conditions[conditionId]
    if not record then
        local tombstone = state.tombstones[conditionId]
        if tombstone then
            publishWeatherCondition(tombstone)
            return deepCopy(tombstone), nil
        end
        return nil, "missing"
    end

    local x, y = record.x, record.y
    local working = deepCopy(state)
    local terminalState = reason == "expired" and "expired" or "abandoned"
    retireCondition(working, conditionId, terminalState, reason or "ended", now())
    pruneTombstones(working, now())
    local saved, saveError = persist(working)
    if not saved then return nil, saveError end
    publishWeatherCondition(state.tombstones[conditionId])
    notifyCoordinate(x, y, reason == "expired" and "expired" or "ended")
    return deepCopy(state.tombstones[conditionId]), nil
end

function CosmicVaultWeatherServer.getWeather(conditionId)
    local available, err = ensureLoaded()
    if not available then return nil, err end
    if type(conditionId) ~= "string" then return nil, "invalid_arguments" end
    local record = state.conditions[conditionId] or state.tombstones[conditionId]
    if not record then return nil, "missing" end
    return deepCopy(record), nil
end

function CosmicVaultWeatherServer.listWeatherAt(x, y)
    local available, err = ensureLoaded()
    if not available then return nil, err end
    if not validCoordinate(x) or not validCoordinate(y) then return nil, "invalid_arguments" end
    return sortedConditionsAt(state, x, y, now()), nil
end

function CosmicVaultWeatherServer.getCoordinateSnapshot(x, y)
    local conditions, err = CosmicVaultWeatherServer.listWeatherAt(x, y)
    if not conditions then return nil, err end
    for _, condition in ipairs(conditions) do
        condition.definition = deepCopy(state.typeDefinitions[condition.weatherType])
    end
    return {schemaVersion = 1, rootRevision = state.revision, x = x, y = y, conditions = conditions}, nil
end

function CosmicVaultWeatherServer.getWeatherSnapshot()
    local available, err = ensureLoaded()
    if not available then return nil, err end
    local snapshot = deepCopy(state)
    local retained = {}
    local count = 0
    for id, tombstone in pairs(snapshot.tombstones) do
        if count >= TOMBSTONE_CAP then break end
        retained[id] = tombstone
        count = count + 1
    end
    snapshot.tombstones = retained
    return snapshot, nil
end

function CosmicVaultWeatherServer.clearLegacyWeather(x, y)
    local weather, err = CosmicVaultWeatherServer.getLegacyWeatherAt(x, y)
    if not weather then return nil, err end
    return CosmicVaultWeatherServer.endWeather(weather.conditionId, "legacy_clear")
end

function CosmicVaultWeatherServer.getLegacyWeatherAt(x, y)
    local records, err = CosmicVaultWeatherServer.listWeatherAt(x, y)
    if not records then return nil, err end
    for _, record in ipairs(records) do
        if record.stackingGroup == "atmosphere" then
            return {
                x = record.x,
                y = record.y,
                type = record.weatherType,
                expiry = record.expiresAt,
                conditionId = record.conditionId,
                sourceId = record.sourceId
            }, nil
        end
    end
    return nil, "missing"
end

function CosmicVaultWeatherServer.createWeather(x, y, stormType, duration)
    return CosmicVaultWeatherServer.startWeather({
        sourceId = "legacy-weather:" .. tostring(x) .. ":" .. tostring(y),
        weatherType = stormType,
        x = x,
        y = y,
        duration = duration or -1,
        conflictPolicy = "replace"
    })
end

function CosmicVaultWeatherServer.removeWeather(x, y)
    return CosmicVaultWeatherServer.clearLegacyWeather(x, y)
end

function CosmicVaultWeatherServer.getWeatherSync(x, y)
    return CosmicVaultWeatherServer.getLegacyWeatherAt(x, y)
end

function CosmicVaultWeatherServer.reportMaterialized(x, y, rootRevision, conditionIds, success, errorText)
    local available, err = ensureLoaded()
    if not available then return nil, err end
    if not validCoordinate(x) or not validCoordinate(y) or type(rootRevision) ~= "number"
            or type(conditionIds) ~= "table" or type(success) ~= "boolean" then
        return nil, "invalid_arguments"
    end
    local working = deepCopy(state)
    local changed = false
    for _, conditionId in ipairs(conditionIds) do
        local condition = working.conditions[conditionId]
        if condition and condition.x == x and condition.y == y then
            condition.revision = (condition.revision or 0) + 1
            condition.updatedAt = now()
            if success then
                condition.materializedRevision = math.max(
                    condition.materializedRevision or 0, rootRevision)
                condition.attempts = 0
                condition.lastError = nil
                if condition.state == "retryable" then condition.state = "active" end
            else
                condition.attempts = (condition.attempts or 0) + 1
                condition.lastError = tostring(errorText or "materialization_failed")
                if condition.attempts >= MAX_ATTEMPTS then
                    condition.state = "repair_required"
                    condition.repairRequired = "materialization_attempts_exhausted"
                else
                    condition.state = "retryable"
                end
            end
            changed = true
        end
    end
    if not changed then return nil, "missing" end
    local saved, saveError = persist(working)
    if not saved then return nil, saveError end
    return true, nil
end

function CosmicVaultWeatherServer.getUpdateInterval()
    return 60
end

function CosmicVaultWeatherServer.updateServer(timeStep)
    local available = ensureLoaded()
    if not available then return end
    local currentTime = now()
    local expired = {}
    for id, condition in pairs(state.conditions) do
        if (condition.state == "active" or condition.state == "retryable")
                and condition.expiresAt ~= -1 and condition.expiresAt <= currentTime then
            table.insert(expired, id)
        end
    end
    for _, id in ipairs(expired) do
        CosmicVaultWeatherServer.endWeather(id, "expired")
    end
    if #expired == 0 then
        local working = deepCopy(state)
        local before = 0
        for _ in pairs(working.tombstones) do before = before + 1 end
        pruneTombstones(working, currentTime)
        local after = 0
        for _ in pairs(working.tombstones) do after = after + 1 end
        if after ~= before then persist(working) end
    end
end

function CosmicVaultWeatherServer.secure()
    return deepCopy(legacyEvidence or legacyRestore or {})
end

function CosmicVaultWeatherServer.restore(data)
    if type(data) == "table" and type(data.activeWeathers) == "table" then
        legacyRestore = deepCopy(data)
        legacyEvidence = deepCopy(data)
    end
    if state then migrateLegacy() end
end
