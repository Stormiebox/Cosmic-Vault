-- namespace CosmicVaultNewsSchema
CosmicVaultNewsSchema = {}

local Schema = CosmicVaultNewsSchema

Schema.ARTICLE_SCHEMA_VERSION = 2
Schema.PUBLISHER_SCHEMA_VERSION = 1
Schema.MANAGER_SCHEMA_VERSION = 2

Schema.LIMITS = {
    publisherId = 48,
    eventId = 160,
    threadId = 160,
    articleId = 220,
    title = 160,
    content = 8192,
    category = 64,
    author = 80,
    outcome = 1024,
    search = 96,
    pageSize = 50,
    provenanceFields = 16,
    provenanceDepth = 3,
    provenanceString = 256,
}

Schema.TOPICS = {
    conflict = true,
    economy = true,
    threat = true,
    discovery = true,
    politics = true,
    humanitarian = true,
    weather = true,
    rift = true,
    captain = true,
    general = true,
}

Schema.SEVERITIES = {
    info = true,
    advisory = true,
    warning = true,
    critical = true,
}

Schema.ARTICLE_STATES = {
    active = true,
    resolved = true,
    expired = true,
    withdrawn = true,
    corrected = true,
}

Schema.AUDIENCE_MODES = {
    galaxy = true,
    region = true,
    faction = true,
    alliance = true,
    player = true,
}

Schema.CANONICAL_PUBLISHERS = {
    cosmic_vault = {schemaVersion = 1, publisherId = "cosmic_vault", displayName = "Cosmic Vault", shortName = "VAULT", color = {r = 0.25, g = 0.9, b = 0.9}},
    cosmic_war = {schemaVersion = 1, publisherId = "cosmic_war", displayName = "Cosmic War", shortName = "WAR", color = {r = 1.0, g = 0.35, b = 0.35}},
    cosmic_overhaul = {schemaVersion = 1, publisherId = "cosmic_overhaul", displayName = "Cosmic Overhaul", shortName = "OVERHAUL", color = {r = 1.0, g = 0.78, b = 0.2}},
    cosmic_chronicles = {schemaVersion = 1, publisherId = "cosmic_chronicles", displayName = "Cosmic Chronicles", shortName = "GNN", color = {r = 0.45, g = 1.0, b = 0.72}},
    cosmic_ascendancy = {schemaVersion = 1, publisherId = "cosmic_ascendancy", displayName = "Cosmic Ascendancy", shortName = "ASC", color = {r = 0.72, g = 0.45, b = 1.0}},
}

local CATEGORY_TOPICS = {
    ["breaking news"] = "threat",
    ["bounty board"] = "conflict",
    ["bounty hunters"] = "conflict",
    ["captain feats"] = "captain",
    ["conflict"] = "conflict",
    ["consumer"] = "economy",
    ["crisis"] = "threat",
    ["discovery"] = "discovery",
    ["eclipse invasion"] = "threat",
    ["economy"] = "economy",
    ["exploration"] = "discovery",
    ["factory"] = "economy",
    ["galactic dread"] = "threat",
    ["galactic expansion"] = "discovery",
    ["galactic milestone"] = "discovery",
    ["galactic threat"] = "threat",
    ["galactic war"] = "conflict",
    ["heroic victories"] = "conflict",
    ["humanitarian"] = "humanitarian",
    ["illegal"] = "threat",
    ["lore anomaly"] = "discovery",
    ["market watch"] = "economy",
    ["military"] = "conflict",
    ["politics"] = "politics",
    ["rift"] = "rift",
    ["trade"] = "economy",
    ["trade crisis"] = "economy",
    ["trading"] = "economy",
    ["war"] = "conflict",
    ["war casualties"] = "conflict",
    ["war crime"] = "conflict",
    ["war heat escalation"] = "conflict",
    ["war update"] = "conflict",
    ["weather"] = "weather",
}

local MUTABLE_ARTICLE_FIELDS = {
    title = true,
    content = true,
    category = true,
    topic = true,
    severity = true,
    breaking = true,
    author = true,
    location = true,
    audience = true,
    lead = true,
    expiresAt = true,
    provenance = true,
}

local PUBLISH_SIGNATURE_FIELDS = {
    "schemaVersion", "articleId", "publisherId", "eventId", "threadId", "eventType",
    "topic", "category", "severity", "breaking", "title", "content", "author",
    "location", "audience", "lead", "expiresAt", "provenance",
}

local function isFinite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function trim(value)
    if type(value) ~= "string" then return value end
    return value:match("^%s*(.-)%s*$")
end

local function cleanTranslationHints(value)
    return (value:gsub("%s*/%*.-%*/%s*", ""))
end

local function boundedText(value, minimum, maximum, allowNil)
    if value == nil and allowNil then return nil, nil end
    if type(value) ~= "string" then return nil, "invalid_text" end

    local normalized = trim(cleanTranslationHints(value))
    if #normalized < minimum or #normalized > maximum then return nil, "invalid_text" end
    return normalized, nil
end

local function identifier(value, maximum, allowNil)
    if value == nil and allowNil then return nil, nil end
    if type(value) ~= "string" or #value < 1 or #value > maximum then return nil, "invalid_id" end
    if not value:match("^[a-z0-9_.:-]+$") then return nil, "invalid_id" end
    return value, nil
end

local function countKeys(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function copySerializable(value, options, depth, seen)
    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "string" then
        if valueType == "string" and options.maxString and #value > options.maxString then
            return nil, "non_serializable"
        end
        return value, nil
    end

    if valueType == "number" then
        if not isFinite(value) then return nil, "non_serializable" end
        return value, nil
    end

    if valueType ~= "table" or getmetatable(value) ~= nil then
        return nil, "non_serializable"
    end

    if depth >= options.maxDepth or seen[value] then return nil, "non_serializable" end
    if countKeys(value) > options.maxFields then return nil, "non_serializable" end

    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        local keyType = type(key)
        if keyType ~= "string" and keyType ~= "number" then
            seen[value] = nil
            return nil, "non_serializable"
        end
        if keyType == "number" and (not isFinite(key) or key % 1 ~= 0) then
            seen[value] = nil
            return nil, "non_serializable"
        end

        local copied, err = copySerializable(child, options, depth + 1, seen)
        if err then
            seen[value] = nil
            return nil, err
        end
        result[key] = copied
    end
    seen[value] = nil
    return result, nil
end

function Schema.DeepCopy(value)
    return copySerializable(value, {maxDepth = 12, maxFields = 4096, maxString = 8192}, 0, {})
end

function Schema.CopyProvenance(value)
    if value == nil then return nil, nil end
    if type(value) ~= "table" then return nil, "invalid_provenance" end
    local copy, err = copySerializable(value, {
        maxDepth = Schema.LIMITS.provenanceDepth,
        maxFields = Schema.LIMITS.provenanceFields,
        maxString = Schema.LIMITS.provenanceString,
    }, 0, {})
    if err then return nil, "invalid_provenance" end
    return copy, nil
end

function Schema.DeepEqual(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end

    for key, value in pairs(left) do
        if not Schema.DeepEqual(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

function Schema.IsIdentifier(value, maximum)
    local result = identifier(value, maximum or Schema.LIMITS.eventId, false)
    return result ~= nil
end

function Schema.BuildArticleId(publisherId, eventId)
    local publisher, publisherError = identifier(publisherId, Schema.LIMITS.publisherId, false)
    if publisherError then return nil, publisherError end
    local event, eventError = identifier(eventId, Schema.LIMITS.eventId, false)
    if eventError then return nil, eventError end

    local articleId = publisher .. ":" .. event
    if #articleId > Schema.LIMITS.articleId then return nil, "invalid_id" end
    return articleId, nil
end

function Schema.StableHash(value)
    if type(value) ~= "string" then return nil, "invalid_text" end
    local hash = 7
    for index = 1, #value do
        hash = (hash * 31 + value:byte(index)) % 2147483647
    end
    return string.format("%08x", hash), nil
end

local function appendCanonical(parts, value)
    local valueType = type(value)
    if valueType == "nil" then
        parts[#parts + 1] = "n;"
    elseif valueType == "boolean" then
        parts[#parts + 1] = value and "b1;" or "b0;"
    elseif valueType == "number" then
        parts[#parts + 1] = "d" .. string.format("%.17g", value) .. ";"
    elseif valueType == "string" then
        parts[#parts + 1] = "s" .. #value .. ":" .. value .. ";"
    elseif valueType == "table" then
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(left, right)
            if type(left) == type(right) then return left < right end
            return type(left) < type(right)
        end)
        parts[#parts + 1] = "t{" 
        for _, key in ipairs(keys) do
            appendCanonical(parts, key)
            appendCanonical(parts, value[key])
        end
        parts[#parts + 1] = "};"
    end
end

function Schema.BuildPublishSignature(article)
    if type(article) ~= "table" then return nil, "invalid_arguments" end
    local parts = {}
    for _, field in ipairs(PUBLISH_SIGNATURE_FIELDS) do
        appendCanonical(parts, field)
        appendCanonical(parts, article[field])
    end
    return Schema.StableHash(table.concat(parts))
end

function Schema.MapCategory(category)
    if type(category) ~= "string" then return "general" end
    local lowered = string.lower(trim(category))
    local mapped = CATEGORY_TOPICS[lowered]
    if mapped then return mapped end
    if lowered:find("weather", 1, true) or lowered:find("storm", 1, true) then return "weather" end
    if lowered:find("rift", 1, true) then return "rift" end
    if lowered:find("war", 1, true) or lowered:find("siege", 1, true) or lowered:find("battle", 1, true) then return "conflict" end
    if lowered:find("market", 1, true) or lowered:find("trade", 1, true) or lowered:find("econom", 1, true) then return "economy" end
    if lowered:find("discover", 1, true) or lowered:find("explor", 1, true) then return "discovery" end
    return "general"
end

function Schema.NormalizePublisher(definition)
    if type(definition) ~= "table" then return nil, "invalid_arguments" end
    if definition.schemaVersion ~= Schema.PUBLISHER_SCHEMA_VERSION then
        return nil, type(definition.schemaVersion) == "number" and "unsupported_version" or "invalid_schema"
    end

    local publisherId, idError = identifier(definition.publisherId, Schema.LIMITS.publisherId, false)
    if idError then return nil, idError end
    local displayName, nameError = boundedText(definition.displayName, 1, 64, false)
    if nameError then return nil, nameError end
    local shortName, shortError = boundedText(definition.shortName, 1, 16, false)
    if shortError then return nil, shortError end
    local icon, iconError = boundedText(definition.icon, 1, 256, true)
    if iconError then return nil, iconError end

    local color
    if definition.color ~= nil then
        if type(definition.color) ~= "table" or getmetatable(definition.color) ~= nil then return nil, "non_serializable" end
        local r, g, b = definition.color.r, definition.color.g, definition.color.b
        if not isFinite(r) or not isFinite(g) or not isFinite(b) then return nil, "non_serializable" end
        if r < 0 or r > 1 or g < 0 or g > 1 or b < 0 or b > 1 then return nil, "invalid_arguments" end
        color = {r = r, g = g, b = b}
    end

    return {
        schemaVersion = Schema.PUBLISHER_SCHEMA_VERSION,
        publisherId = publisherId,
        displayName = displayName,
        shortName = shortName,
        icon = icon,
        color = color,
    }, nil
end

function Schema.NormalizeLocation(location, allowNil)
    if location == nil and allowNil then return nil, nil end
    if type(location) ~= "table" or getmetatable(location) ~= nil then return nil, "invalid_location" end
    if not isFinite(location.x) or not isFinite(location.y) then return nil, "invalid_location" end

    local x = math.floor(location.x)
    local y = math.floor(location.y)
    local radius = location.radius == nil and 0 or location.radius
    if not isFinite(radius) or radius < 0 or radius > 500 then return nil, "invalid_location" end
    return {x = x, y = y, radius = radius}, nil
end

function Schema.NormalizeAudience(audience, location)
    if audience == nil then return {mode = "galaxy"}, nil end
    if type(audience) ~= "table" or getmetatable(audience) ~= nil then return nil, "invalid_audience" end
    if not Schema.AUDIENCE_MODES[audience.mode] then return nil, "invalid_audience" end

    local result = {mode = audience.mode}
    if audience.mode == "region" then
        if not location then return nil, "invalid_audience" end
    elseif audience.mode == "faction" then
        if not isFinite(audience.factionIndex) or audience.factionIndex % 1 ~= 0 then return nil, "invalid_audience" end
        result.factionIndex = audience.factionIndex
    elseif audience.mode == "alliance" then
        if not isFinite(audience.allianceIndex) or audience.allianceIndex % 1 ~= 0 then return nil, "invalid_audience" end
        result.allianceIndex = audience.allianceIndex
    elseif audience.mode == "player" then
        if not isFinite(audience.playerIndex) or audience.playerIndex % 1 ~= 0 then return nil, "invalid_audience" end
        result.playerIndex = audience.playerIndex
    end
    return result, nil
end

function Schema.NormalizeLead(lead, publisherId, allowNil)
    if lead == nil and allowNil then return nil, nil end
    if type(lead) ~= "table" or getmetatable(lead) ~= nil then return nil, "invalid_arguments" end
    if lead.kind ~= "location" then return nil, "invalid_arguments" end
    if not isFinite(lead.x) or not isFinite(lead.y) then return nil, "invalid_location" end

    local ownerId = lead.ownerId or publisherId
    local normalizedOwner, ownerError = identifier(ownerId, Schema.LIMITS.publisherId, false)
    if ownerError then return nil, ownerError end
    if lead.expiresAt ~= nil and not isFinite(lead.expiresAt) then return nil, "invalid_expiry" end

    return {
        kind = "location",
        ownerId = normalizedOwner,
        x = math.floor(lead.x),
        y = math.floor(lead.y),
        expiresAt = lead.expiresAt,
    }, nil
end

function Schema.NormalizeArticle(options)
    if type(options) ~= "table" then return nil, "invalid_arguments" end
    if options.schemaVersion ~= Schema.ARTICLE_SCHEMA_VERSION then
        return nil, type(options.schemaVersion) == "number" and "unsupported_version" or "invalid_schema"
    end

    local publisherId, publisherError = identifier(options.publisherId, Schema.LIMITS.publisherId, false)
    if publisherError then return nil, publisherError end
    local eventId, eventError = identifier(options.eventId, Schema.LIMITS.eventId, false)
    if eventError then return nil, eventError end
    local articleId, articleError = Schema.BuildArticleId(publisherId, eventId)
    if articleError then return nil, articleError end
    local threadId, threadError = identifier(options.threadId, Schema.LIMITS.threadId, true)
    if threadError then return nil, threadError end
    local eventType, eventTypeError = identifier(options.eventType, Schema.LIMITS.eventId, false)
    if eventTypeError then return nil, eventTypeError end

    local topic = options.topic
    if not Schema.TOPICS[topic] then return nil, "invalid_topic" end
    local severity = options.severity or "info"
    if not Schema.SEVERITIES[severity] then return nil, "invalid_severity" end

    local title, titleError = boundedText(options.title, 1, Schema.LIMITS.title, false)
    if titleError then return nil, titleError end
    local content, contentError = boundedText(options.content, 1, Schema.LIMITS.content, false)
    if contentError then return nil, contentError end
    local category, categoryError = boundedText(options.category or "General", 1, Schema.LIMITS.category, false)
    if categoryError then return nil, categoryError end
    local author, authorError = boundedText(options.author, 1, Schema.LIMITS.author, true)
    if authorError then return nil, authorError end

    local location, locationError = Schema.NormalizeLocation(options.location, true)
    if locationError then return nil, locationError end
    local audience, audienceError = Schema.NormalizeAudience(options.audience, location)
    if audienceError then return nil, audienceError end
    local lead, leadError = Schema.NormalizeLead(options.lead, publisherId, true)
    if leadError then return nil, leadError end
    local provenance, provenanceError = Schema.CopyProvenance(options.provenance)
    if provenanceError then return nil, provenanceError end

    if options.expiresAt ~= nil and not isFinite(options.expiresAt) then return nil, "invalid_expiry" end
    if options.state ~= nil and options.state ~= "active" then return nil, "invalid_state" end

    return {
        schemaVersion = Schema.ARTICLE_SCHEMA_VERSION,
        articleId = articleId,
        publisherId = publisherId,
        eventId = eventId,
        threadId = threadId,
        eventType = eventType,
        topic = topic,
        category = category,
        severity = severity,
        breaking = options.breaking == true,
        title = title,
        content = content,
        author = author,
        location = location,
        audience = audience,
        lead = lead,
        state = "active",
        expiresAt = options.expiresAt,
        provenance = provenance,
    }, nil
end

function Schema.NormalizePatch(patch, current)
    if type(patch) ~= "table" or type(current) ~= "table" then return nil, "invalid_arguments" end
    local candidate, copyError = Schema.DeepCopy(current)
    if copyError then return nil, "corrupt_record" end

    for field, value in pairs(patch) do
        if not MUTABLE_ARTICLE_FIELDS[field] then return nil, "invalid_arguments" end
        candidate[field] = value
    end

    local normalized, normalizeError = Schema.NormalizeArticle(candidate)
    if normalizeError then return nil, normalizeError end
    normalized.articleId = current.articleId
    normalized.sequence = current.sequence
    normalized.revision = current.revision
    normalized.publishedAt = current.publishedAt
    normalized.updatedAt = current.updatedAt
    normalized.resolvedAt = current.resolvedAt
    normalized.outcome = current.outcome
    return normalized, nil
end

function Schema.NormalizeResolution(resolution)
    if type(resolution) ~= "table" then return nil, "invalid_arguments" end
    local state = resolution.state or "resolved"
    if state ~= "resolved" and state ~= "expired" and state ~= "withdrawn" and state ~= "corrected" then
        return nil, "invalid_state"
    end
    local outcome, outcomeError = boundedText(resolution.outcome, 1, Schema.LIMITS.outcome, true)
    if outcomeError then return nil, outcomeError end
    return {state = state, outcome = outcome}, nil
end

function Schema.NormalizeLegacyArticle(article, eventId)
    if type(article) ~= "table" then return nil, "invalid_arguments" end
    local normalizedEventId, eventError = identifier(eventId, Schema.LIMITS.eventId, false)
    if eventError then return nil, eventError end

    local category = type(article.category) == "string" and article.category or "General"
    local options = {
        schemaVersion = Schema.ARTICLE_SCHEMA_VERSION,
        publisherId = "cosmic_vault",
        eventId = normalizedEventId,
        eventType = "legacy.news.published",
        topic = Schema.MapCategory(category),
        category = category,
        severity = article.breaking == true and "critical" or "info",
        breaking = article.breaking == true,
        title = article.title,
        content = article.content,
        author = article.author,
        audience = {mode = "galaxy"},
        provenance = {recordType = "legacy_v1", sourceRevision = 0},
    }
    return Schema.NormalizeArticle(options)
end

function Schema.GetCanonicalPublishers()
    local copy = Schema.DeepCopy(Schema.CANONICAL_PUBLISHERS)
    return copy or {}
end

return CosmicVaultNewsSchema
