local NewsSchema = include("cosmicvaultnews_schema")

-- namespace CosmicVaultDialogueSchema
CosmicVaultDialogueSchema = {}
local Schema = CosmicVaultDialogueSchema

Schema.ENTRY_SCHEMA_VERSION = 2
Schema.PUBLISHER_SCHEMA_VERSION = 1
Schema.MANAGER_SCHEMA_VERSION = 2

Schema.LIMITS = {
    publisherId = 48,
    lineId = 180,
    category = 48,
    text = 1024,
    tag = 32,
    tags = 16,
    entriesPerCall = 256,
    catalogEntries = 4096,
    excludeIds = 32,
    queryResults = 25,
}

local NUMERIC_CONDITIONS = {
    minWarHeat = true,
    maxWarHeat = true,
    minReputation = true,
    maxReputation = true,
    minDistanceToCenter = true,
    maxDistanceToCenter = true,
}

local SET_CONDITIONS = {
    stationTypes = true,
    factionTraits = true,
    factionWealth = true,
    publisherIds = true,
    topics = true,
    severities = true,
    weatherTypes = true,
    eclipseStates = true,
    captainClasses = true,
}

local CONDITION_KEYS = {
    riftActive = true,
}
for key in pairs(NUMERIC_CONDITIONS) do CONDITION_KEYS[key] = true end
for key in pairs(SET_CONDITIONS) do CONDITION_KEYS[key] = true end

local NUMERIC_CONTEXT = {warHeat = true, reputation = true, distanceToCenter = true}
local STRING_CONTEXT = {
    stationType = true,
    factionTrait = true,
    factionWealth = true,
    publisherId = true,
    topic = true,
    severity = true,
    weatherType = true,
    eclipseState = true,
    captainClass = true,
}
local SET_CONTEXT = {
    stationTypes = true,
    factionTraits = true,
    publisherIds = true,
    topics = true,
    severities = true,
    weatherTypes = true,
    eclipseStates = true,
    captainClasses = true,
}

local function isFinite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function trim(value)
    if type(value) ~= "string" then return value end
    return value:match("^%s*(.-)%s*$")
end

local function normalizeIdentifier(value, maximum)
    if type(value) ~= "string" or #value < 1 or #value > maximum then return nil, "invalid_id" end
    if not value:match("^[a-z0-9_.:-]+$") then return nil, "invalid_id" end
    return value, nil
end

local function normalizeText(value, minimum, maximum, errorCode)
    if type(value) ~= "string" then return nil, errorCode end
    local result = trim(value)
    if #result < minimum or #result > maximum then return nil, errorCode end
    return result, nil
end

local function normalizeSet(values, maximum)
    if values == nil then return nil, nil end
    if type(values) ~= "table" or getmetatable(values) ~= nil then return nil, "invalid_conditions" end
    local result = {}
    local count = 0
    for key, value in pairs(values) do
        if type(key) ~= "number" and type(value) ~= "boolean" then return nil, "invalid_conditions" end
        local entry = type(key) == "number" and value or key
        local enabled = type(key) == "number" or value == true
        if enabled then
            if type(entry) ~= "string" or entry == "" or #entry > 64 then return nil, "invalid_conditions" end
            result[entry] = true
            count = count + 1
            if count > maximum then return nil, "invalid_conditions" end
        end
    end
    return result, nil
end

local function normalizeTags(tags)
    if tags == nil then return {}, nil end
    if type(tags) ~= "table" or getmetatable(tags) ~= nil then return nil, "invalid_tags" end
    local result = {}
    local seen = {}
    for _, tag in ipairs(tags) do
        local normalized, tagError = normalizeText(tag, 1, Schema.LIMITS.tag, "invalid_tags")
        if tagError then return nil, tagError end
        if not seen[normalized] then
            result[#result + 1] = normalized
            seen[normalized] = true
            if #result > Schema.LIMITS.tags then return nil, "invalid_tags" end
        end
    end
    return result, nil
end

function Schema.NormalizeConditions(conditions)
    if conditions == nil then return {}, nil end
    if type(conditions) ~= "table" or getmetatable(conditions) ~= nil then return nil, "invalid_conditions" end

    local result = {}
    for key, value in pairs(conditions) do
        if not CONDITION_KEYS[key] then return nil, "unsupported_predicate" end
        if NUMERIC_CONDITIONS[key] then
            if not isFinite(value) then return nil, "invalid_conditions" end
            result[key] = value
        elseif SET_CONDITIONS[key] then
            local normalized, setError = normalizeSet(value, 32)
            if setError then return nil, setError end
            result[key] = normalized
        elseif key == "riftActive" then
            if type(value) ~= "boolean" then return nil, "invalid_conditions" end
            result[key] = value
        end
    end
    return result, nil
end

function Schema.NormalizePublisher(definition)
    local _, copyError = NewsSchema.DeepCopy(definition)
    if copyError then return nil, "non_serializable" end
    return NewsSchema.NormalizePublisher(definition)
end

function Schema.NormalizeEntry(publisherId, entry)
    local normalizedPublisher, publisherError = normalizeIdentifier(publisherId, Schema.LIMITS.publisherId)
    if publisherError then return nil, publisherError end
    if type(entry) ~= "table" then return nil, "invalid_arguments" end
    local copiedEntry, copyError = NewsSchema.DeepCopy(entry)
    if copyError then return nil, "non_serializable" end
    entry = copiedEntry
    if entry.schemaVersion ~= Schema.ENTRY_SCHEMA_VERSION then
        return nil, type(entry.schemaVersion) == "number" and "unsupported_version" or "invalid_schema"
    end

    local lineId, lineError = normalizeIdentifier(entry.lineId, Schema.LIMITS.lineId)
    if lineError then return nil, lineError end
    if lineId:sub(1, #normalizedPublisher + 1) ~= normalizedPublisher .. ":" then return nil, "invalid_id" end
    local category, categoryError = normalizeText(entry.category, 1, Schema.LIMITS.category, "invalid_category")
    if categoryError then return nil, categoryError end
    local text, textError = normalizeText(entry.text, 1, Schema.LIMITS.text, "invalid_text")
    if textError then return nil, textError end
    local weight = entry.weight == nil and 1 or entry.weight
    if not isFinite(weight) or weight < 0.01 or weight > 100 then return nil, "invalid_weight" end
    local tags, tagsError = normalizeTags(entry.tags)
    if tagsError then return nil, tagsError end
    local conditions, conditionsError = Schema.NormalizeConditions(entry.conditions)
    if conditionsError then return nil, conditionsError end

    return {
        schemaVersion = Schema.ENTRY_SCHEMA_VERSION,
        publisherId = normalizedPublisher,
        lineId = lineId,
        category = category,
        text = text,
        weight = weight,
        tags = tags,
        conditions = conditions,
    }, nil
end

local function legacyPublisherId(entry)
    local raw = type(entry.modId) == "string" and entry.modId or "legacy"
    local compact = string.lower(raw):gsub("[^a-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if compact == "cosmicchronicles" then compact = "cosmic_chronicles" end
    if compact == "cosmicascendancy" then compact = "cosmic_ascendancy" end
    if compact == "" then compact = "legacy" end
    return compact:sub(1, Schema.LIMITS.publisherId)
end

function Schema.NormalizeLegacyEntry(entry)
    if type(entry) ~= "table" then return nil, "invalid_arguments" end
    local copiedEntry, copyError = NewsSchema.DeepCopy(entry)
    if copyError then return nil, "non_serializable" end
    entry = copiedEntry
    local category, categoryError = normalizeText(entry.category, 1, Schema.LIMITS.category, "invalid_category")
    if categoryError then return nil, categoryError end
    local text, textError = normalizeText(entry.text, 1, Schema.LIMITS.text, "invalid_text")
    if textError then return nil, textError end
    local publisherId = legacyPublisherId(entry)

    local legacyConditions = entry.conditions or {}
    if type(legacyConditions) ~= "table" or getmetatable(legacyConditions) ~= nil then return nil, "invalid_conditions" end
    local converted = {}
    for key, value in pairs(legacyConditions) do
        if key == "stationType" then
            converted.stationTypes = {[value] = true}
        elseif key == "factionTrait" then
            converted.factionTraits = {[value] = true}
        elseif key == "factionWealth" then
            converted.factionWealth = {[value] = true}
        else
            converted[key] = value
        end
    end

    local hash, hashError = NewsSchema.StableHash(string.lower(category) .. "\n" .. text)
    if hashError then return nil, hashError end
    local categoryId = string.lower(category):gsub("[^a-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    if categoryId == "" then categoryId = "general" end
    return Schema.NormalizeEntry(publisherId, {
        schemaVersion = Schema.ENTRY_SCHEMA_VERSION,
        lineId = publisherId .. ":legacy:" .. categoryId:sub(1, 32) .. ":" .. hash,
        category = category,
        text = text,
        weight = entry.weight or 1,
        tags = entry.tags or {"legacy"},
        conditions = converted,
    })
end

local function contextContains(contextValue, expectedSet)
    if type(contextValue) == "string" then return expectedSet[contextValue] == true end
    if type(contextValue) ~= "table" then return false end
    for key, value in pairs(contextValue) do
        local entry = type(key) == "number" and value or key
        local enabled = type(key) == "number" or value == true
        if enabled and expectedSet[entry] then return true end
    end
    return false
end

function Schema.Matches(entry, context)
    if type(entry) ~= "table" or type(context) ~= "table" then return false, "unsupported_context" end
    local conditions = entry.conditions or {}
    local warHeat = tonumber(context.warHeat) or 0
    local reputation = tonumber(context.reputation) or 0
    local distance = tonumber(context.distanceToCenter) or 500

    if conditions.minWarHeat and warHeat < conditions.minWarHeat then return false end
    if conditions.maxWarHeat and warHeat > conditions.maxWarHeat then return false end
    if conditions.minReputation and reputation < conditions.minReputation then return false end
    if conditions.maxReputation and reputation > conditions.maxReputation then return false end
    if conditions.minDistanceToCenter and distance < conditions.minDistanceToCenter then return false end
    if conditions.maxDistanceToCenter and distance > conditions.maxDistanceToCenter then return false end
    if conditions.stationTypes and not contextContains(context.stationType or context.stationTypes, conditions.stationTypes) then return false end
    if conditions.factionTraits and not contextContains(context.factionTrait or context.factionTraits, conditions.factionTraits) then return false end
    if conditions.factionWealth and not contextContains(context.factionWealth, conditions.factionWealth) then return false end
    if conditions.publisherIds and not contextContains(context.publisherId or context.publisherIds, conditions.publisherIds) then return false end
    if conditions.topics and not contextContains(context.topic or context.topics, conditions.topics) then return false end
    if conditions.severities and not contextContains(context.severity or context.severities, conditions.severities) then return false end
    if conditions.weatherTypes and not contextContains(context.weatherType or context.weatherTypes, conditions.weatherTypes) then return false end
    if conditions.eclipseStates and not contextContains(context.eclipseState or context.eclipseStates, conditions.eclipseStates) then return false end
    if conditions.captainClasses and not contextContains(context.captainClass or context.captainClasses, conditions.captainClasses) then return false end
    if conditions.riftActive ~= nil and context.riftActive ~= conditions.riftActive then return false end
    return true, nil
end

function Schema.NormalizeExcludeIds(excludeIds)
    if excludeIds == nil then return {}, nil end
    local values, valuesError = normalizeSet(excludeIds, Schema.LIMITS.excludeIds)
    if valuesError then return nil, "invalid_arguments" end
    for lineId in pairs(values) do
        if not normalizeIdentifier(lineId, Schema.LIMITS.lineId) then return nil, "invalid_id" end
    end
    return values, nil
end

function Schema.NormalizeContext(context)
    context = context or {}
    if type(context) ~= "table" or getmetatable(context) ~= nil then return nil, "unsupported_context" end
    local result = {}
    for key, value in pairs(context) do
        if NUMERIC_CONTEXT[key] then
            if not isFinite(value) then return nil, "unsupported_context" end
            result[key] = value
        elseif STRING_CONTEXT[key] then
            local normalized, textError = normalizeText(value, 1, 64, "unsupported_context")
            if textError then return nil, textError end
            result[key] = normalized
        elseif SET_CONTEXT[key] then
            local normalized, setError = normalizeSet(value, 32)
            if setError then return nil, "unsupported_context" end
            result[key] = normalized
        elseif key == "riftActive" then
            if type(value) ~= "boolean" then return nil, "unsupported_context" end
            result[key] = value
        else
            return nil, "unsupported_context"
        end
    end
    return result, nil
end

function Schema.SelectWeighted(entries, seed)
    if type(entries) ~= "table" or #entries == 0 then return nil, "not_found" end
    if type(seed) ~= "number" or seed ~= seed or seed == math.huge or seed == -math.huge then return nil, "invalid_arguments" end

    local total = 0
    for _, entry in ipairs(entries) do total = total + entry.weight end
    if total <= 0 then return nil, "not_found" end
    local state = (math.floor(math.abs(seed)) * 1103515245 + 12345) % 2147483648
    local target = (state / 2147483648) * total
    local cursor = 0
    for _, entry in ipairs(entries) do
        cursor = cursor + entry.weight
        if target < cursor then return NewsSchema.DeepCopy(entry) end
    end
    return NewsSchema.DeepCopy(entries[#entries])
end

function Schema.DeepCopy(value)
    return NewsSchema.DeepCopy(value)
end

return CosmicVaultDialogueSchema
