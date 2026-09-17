local Schema = include("cosmicvaultnews_schema")
local Debug = include("cosmicvaultdebug")

-- namespace CosmicVaultNewsServer
CosmicVaultNewsServer = {}
local self = CosmicVaultNewsServer

local ACTIVE_LIMIT = 128
local ARCHIVE_LIMIT = 384
local TOTAL_LIMIT = 512
local TOMBSTONE_LIMIT = 2048
local TOMBSTONE_TTL = 90 * 24 * 60 * 60
local REPAIR_LIMIT = 128
local MAINTENANCE_BATCH = 16

local reporters = {
    "Jade", "Kaelen", "Lyra", "Dax", "Rylan", "Vex", "Elara", "Talon", "Nova", "Silas",
    "Zyx", "Corin", "Tali", "Jarek", "Reyna", "Orion", "Kass", "Vesper", "Thorne", "Anya",
    "Soren", "Kael", "Zander", "Nyx", "Kira", "Vance", "Elena", "Torin", "Sera", "Ronan",
    "Mila", "Cade", "Lira", "Gael", "Tess",
}

self.record = nil
self.pendingNotifications = {}

local function serverTime()
    local server = Server()
    return server and server.unpausedRuntime or 0
end

local function tableCount(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

local function newRecord()
    return {
        schemaVersion = Schema.MANAGER_SCHEMA_VERSION,
        revision = 0,
        feedRevision = 0,
        nextSequence = 1,
        active = {},
        archive = {},
        publishers = {},
        tombstones = {},
        migration = {state = "pending", version = 0, legacyV1 = nil, imported = 0, lastError = nil},
        repairFindings = {},
        nextRepairId = 1,
        lastError = nil,
    }
end

local function ensureRecordShape(record)
    if type(record) ~= "table" or record.schemaVersion ~= Schema.MANAGER_SCHEMA_VERSION then return false end
    if type(record.revision) ~= "number" or type(record.feedRevision) ~= "number" or type(record.nextSequence) ~= "number" then return false end
    if type(record.active) ~= "table" or type(record.archive) ~= "table" or type(record.publishers) ~= "table" then return false end
    if type(record.tombstones) ~= "table" or type(record.repairFindings) ~= "table" then return false end
    if type(record.migration) ~= "table" then return false end
    record.nextRepairId = tonumber(record.nextRepairId) or 1
    return true
end

local function debugError(message, ...)
    if Debug and Debug.error then Debug.error("CosmicVaultNews", message, ...) end
end

local function debugInfo(message, ...)
    if Debug and Debug.info then Debug.info("CosmicVaultNews", message, ...) end
end

local function defensiveCopy(value)
    local copy, err = Schema.DeepCopy(value)
    if err then return nil, "corrupt_record" end
    return copy, nil
end

local function addRepair(kind, evidence)
    local record = self.record
    local repairId = "news:" .. tostring(record.nextRepairId)
    record.nextRepairId = record.nextRepairId + 1

    local copiedEvidence = Schema.CopyProvenance(evidence)
    record.repairFindings[#record.repairFindings + 1] = {
        schemaVersion = 1,
        repairId = repairId,
        kind = kind,
        state = "open",
        createdAt = serverTime(),
        evidence = copiedEvidence or {},
    }
    while #record.repairFindings > REPAIR_LIMIT do table.remove(record.repairFindings, 1) end
    record.revision = record.revision + 1
    return repairId
end

local function queueNotification(articleId, changeType)
    self.record.feedRevision = self.record.feedRevision + 1
    self.record.revision = self.record.revision + 1
    self.pendingNotifications[#self.pendingNotifications + 1] = {
        feedRevision = self.record.feedRevision,
        articleId = articleId,
        changeType = changeType,
    }
    if #self.pendingNotifications > 256 then table.remove(self.pendingNotifications, 1) end
end

local function getStoredArticle(articleId)
    local article = self.record.active[articleId]
    if article then return article, "active" end
    article = self.record.archive[articleId]
    if article then return article, "archive" end
    return nil, nil
end

local function assignReporter(article)
    if article.author then return end
    local hash = Schema.StableHash(article.articleId)
    local value = tonumber(hash, 16) or 1
    article.author = reporters[(value % #reporters) + 1]
end

local function registerPublisherInternal(definition)
    local normalized, normalizeError = Schema.NormalizePublisher(definition)
    if normalizeError then return nil, normalizeError end

    local existing = self.record.publishers[normalized.publisherId]
    if existing then
        if Schema.DeepEqual(existing, normalized) then
            local copy = defensiveCopy(existing)
            return copy, nil, false
        end
        addRepair("publisher_conflict", {publisherId = normalized.publisherId})
        return nil, "publisher_conflict"
    end

    self.record.publishers[normalized.publisherId] = normalized
    self.record.revision = self.record.revision + 1
    local copy = defensiveCopy(normalized)
    return copy, nil, true
end

local function registerCanonicalPublishers()
    local definitions = Schema.GetCanonicalPublishers()
    local ids = {"cosmic_vault", "cosmic_war", "cosmic_overhaul", "cosmic_chronicles", "cosmic_ascendancy"}
    for _, publisherId in ipairs(ids) do
        local _, err = registerPublisherInternal(definitions[publisherId])
        if err then debugError("Canonical publisher %s could not be registered: %s", publisherId, err) end
    end
end

local function ensureRuntimeRecord()
    if self.record then return end
    self.record = newRecord()
    registerCanonicalPublishers()
end

local function normalizeSet(values, maximum)
    if values == nil then return nil, nil end
    if type(values) ~= "table" then return nil, "invalid_arguments" end
    local result = {}
    local count = 0
    for key, value in pairs(values) do
        local entry = type(key) == "number" and value or key
        local enabled = type(key) == "number" or value == true
        if enabled then
            if type(entry) ~= "string" then return nil, "invalid_arguments" end
            result[entry] = true
            count = count + 1
            if count > maximum then return nil, "invalid_arguments" end
        end
    end
    return result, nil
end

local function isAudienceVisible(article, playerIndex)
    local audience = article.audience or {mode = "galaxy"}
    if audience.mode == "galaxy" then return true end
    if type(playerIndex) ~= "number" then return false end

    local player = Player(playerIndex)
    if not player then return false end
    if audience.mode == "player" then return player.index == audience.playerIndex end
    if audience.mode == "alliance" then return player.allianceIndex == audience.allianceIndex end
    if audience.mode == "faction" then return player.index == audience.factionIndex end
    if audience.mode == "region" then
        if not article.location then return false end
        local x, y = player:getSectorCoordinates()
        if type(x) ~= "number" or type(y) ~= "number" then return false end
        local dx = x - article.location.x
        local dy = y - article.location.y
        return dx * dx + dy * dy <= article.location.radius * article.location.radius
    end
    return false
end

local function matchesLocation(article, location)
    if not location then return true end
    if not article.location then return false end
    local dx = location.x - article.location.x
    local dy = location.y - article.location.y
    local radius = location.radius + article.location.radius
    return dx * dx + dy * dy <= radius * radius
end

local function matchesQuery(article, query)
    if query.beforeSequence and article.sequence >= query.beforeSequence then return false end
    if query.states and not query.states[article.state] then return false end
    if query.publisherIds and not query.publisherIds[article.publisherId] then return false end
    if query.topics and not query.topics[article.topic] then return false end
    if query.threadId and article.threadId ~= query.threadId then return false end
    if not matchesLocation(article, query.location) then return false end
    if not isAudienceVisible(article, query.audiencePlayerIndex) then return false end
    if query.search then
        local haystack = string.lower((article.title or "") .. "\n" .. (article.content or "") .. "\n" .. (article.category or ""))
        if not haystack:find(query.search, 1, true) then return false end
    end
    return true
end

local function normalizeQuery(options)
    options = options or {}
    if type(options) ~= "table" then return nil, "invalid_arguments" end

    local pageSize = tonumber(options.pageSize) or 30
    pageSize = math.max(1, math.min(Schema.LIMITS.pageSize, math.floor(pageSize)))
    local beforeSequence = options.beforeSequence
    if beforeSequence ~= nil and (type(beforeSequence) ~= "number" or beforeSequence % 1 ~= 0 or beforeSequence < 1) then
        return nil, "invalid_arguments"
    end
    local ifRevision = options.ifRevision
    if ifRevision ~= nil and (type(ifRevision) ~= "number" or ifRevision % 1 ~= 0 or ifRevision < 0) then
        return nil, "invalid_arguments"
    end
    if options.audiencePlayerIndex ~= nil and (type(options.audiencePlayerIndex) ~= "number" or options.audiencePlayerIndex % 1 ~= 0) then
        return nil, "invalid_audience"
    end

    local states, statesError = normalizeSet(options.states, 5)
    if statesError then return nil, statesError end
    if not states then
        states = {active = true}
        if options.includeArchive == true then
            states.resolved = true
            states.expired = true
            states.withdrawn = true
            states.corrected = true
        end
    end
    for state in pairs(states) do
        if not Schema.ARTICLE_STATES[state] then return nil, "invalid_state" end
    end

    local publisherIds, publisherError = normalizeSet(options.publisherIds, 16)
    if publisherError then return nil, publisherError end
    local topics, topicsError = normalizeSet(options.topics, 16)
    if topicsError then return nil, topicsError end
    if topics then
        for topic in pairs(topics) do
            if not Schema.TOPICS[topic] then return nil, "invalid_topic" end
        end
    end

    local threadId
    if options.threadId ~= nil then
        if not Schema.IsIdentifier(options.threadId, Schema.LIMITS.threadId) then return nil, "invalid_id" end
        threadId = options.threadId
    end
    local search
    if options.search ~= nil then
        if type(options.search) ~= "string" or #options.search > Schema.LIMITS.search then return nil, "invalid_text" end
        search = string.lower(options.search:match("^%s*(.-)%s*$"))
        if search == "" then search = nil end
    end
    local location, locationError = Schema.NormalizeLocation(options.location, true)
    if locationError then return nil, locationError end

    return {
        pageSize = pageSize,
        beforeSequence = beforeSequence,
        ifRevision = ifRevision,
        states = states,
        publisherIds = publisherIds,
        topics = topics,
        threadId = threadId,
        search = search,
        location = location,
        audiencePlayerIndex = options.audiencePlayerIndex,
        includeArchive = options.includeArchive == true,
    }, nil
end

local function archiveArticle(article, changeType)
    self.record.active[article.articleId] = nil
    self.record.archive[article.articleId] = article
    queueNotification(article.articleId, changeType)
end

local function addTombstone(article)
    local now = serverTime()
    self.record.tombstones[article.articleId] = {
        schemaVersion = 1,
        articleId = article.articleId,
        publisherId = article.publisherId,
        eventId = article.eventId,
        sequence = article.sequence,
        revision = article.revision,
        initialSignature = article.initialSignature,
        prunedAt = now,
        expiresAt = now + TOMBSTONE_TTL,
    }
end

local function findOldest(collection, predicate)
    local oldest
    for _, article in pairs(collection) do
        if (not predicate or predicate(article)) and (not oldest or article.sequence < oldest.sequence) then oldest = article end
    end
    return oldest
end

local function expireActive(limit)
    local now = serverTime()
    local changed = 0
    local due = {}
    for _, article in pairs(self.record.active) do
        if article.expiresAt and article.expiresAt <= now then due[#due + 1] = article end
    end
    table.sort(due, function(left, right) return left.sequence < right.sequence end)
    for _, article in ipairs(due) do
        if changed >= limit then break end
        article.state = "expired"
        article.revision = article.revision + 1
        article.updatedAt = now
        article.resolvedAt = now
        archiveArticle(article, "expired")
        changed = changed + 1
    end
    return changed
end

local function enforceBounds(limit)
    local changed = 0
    local now = serverTime()

    while tableCount(self.record.active) > ACTIVE_LIMIT and changed < limit do
        local article = findOldest(self.record.active, function(candidate) return candidate.severity ~= "critical" end)
        if not article then
            self.record.lastError = "active_critical_limit"
            break
        end
        article.state = "expired"
        article.revision = article.revision + 1
        article.updatedAt = now
        article.resolvedAt = now
        article.outcome = "Moved to archive by the bounded active-feed policy."
        archiveArticle(article, "archived")
        changed = changed + 1
    end

    while (tableCount(self.record.archive) > ARCHIVE_LIMIT or tableCount(self.record.active) + tableCount(self.record.archive) > TOTAL_LIMIT) and changed < limit do
        local article = findOldest(self.record.archive)
        if not article then break end
        self.record.archive[article.articleId] = nil
        addTombstone(article)
        queueNotification(article.articleId, "pruned")
        changed = changed + 1
    end

    local expiredTombstones = {}
    for articleId, tombstone in pairs(self.record.tombstones) do
        if tombstone.expiresAt <= now then expiredTombstones[#expiredTombstones + 1] = articleId end
    end
    table.sort(expiredTombstones)
    for _, articleId in ipairs(expiredTombstones) do
        if changed >= limit then break end
        self.record.tombstones[articleId] = nil
        self.record.revision = self.record.revision + 1
        changed = changed + 1
    end

    while tableCount(self.record.tombstones) > TOMBSTONE_LIMIT and changed < limit do
        local oldestId
        local oldest
        for articleId, tombstone in pairs(self.record.tombstones) do
            if not oldest or tombstone.prunedAt < oldest.prunedAt then
                oldest = tombstone
                oldestId = articleId
            end
        end
        if not oldestId then break end
        self.record.tombstones[oldestId] = nil
        self.record.revision = self.record.revision + 1
        changed = changed + 1
    end
end

local function importLegacy(legacyNews)
    local record = newRecord()
    self.record = record
    registerCanonicalPublishers()

    local original, copyError = defensiveCopy(legacyNews or {})
    record.migration.legacyV1 = original or {}
    if copyError then
        record.migration.state = "repair_required"
        record.migration.lastError = copyError
        addRepair("legacy_feed_corrupt", {reason = copyError})
        return
    end

    for index = #legacyNews, 1, -1 do
        local legacy = legacyNews[index]
        if type(legacy) == "table" then
            local identityText = tostring(legacy.timestamp or 0) .. "|" .. tostring(legacy.title or "") .. "|" .. tostring(index)
            local hash = Schema.StableHash(identityText)
            local normalized, normalizeError = Schema.NormalizeLegacyArticle(legacy, "legacy:" .. tostring(hash) .. ":" .. tostring(index))
            if normalized then
                normalized.sequence = record.nextSequence
                record.nextSequence = record.nextSequence + 1
                normalized.revision = 0
                normalized.publishedAt = type(legacy.timestamp) == "number" and legacy.timestamp or 0
                normalized.updatedAt = normalized.publishedAt
                assignReporter(normalized)
                normalized.initialSignature = Schema.BuildPublishSignature(normalized)
                record.active[normalized.articleId] = normalized
                record.migration.imported = record.migration.imported + 1
            else
                addRepair("legacy_article_invalid", {ordinal = index, reason = normalizeError})
            end
        end
    end

    record.feedRevision = record.migration.imported
    record.revision = record.revision + 1
    record.migration.state = "complete"
    record.migration.version = 2
end

function CosmicVaultNewsServer.initialize()
    if not onServer() then return end
    if not self.record then self.record = newRecord() end
    registerCanonicalPublishers()
    Server():registerCallback("onCCNewsSyncRequest", "onSyncRequest")
    Server():registerCallback("onCCNewsPublishArticle", "onPublishArticle")
    debugInfo("News v2 manager initialized at feed revision %s.", tostring(self.record.feedRevision))
end

function CosmicVaultNewsServer.registerPublisher(definition)
    if not onServer() then return nil, "server_only" end
    ensureRuntimeRecord()
    return registerPublisherInternal(definition)
end

function CosmicVaultNewsServer.publish(options)
    if not onServer() then return nil, "server_only" end
    ensureRuntimeRecord()
    local normalized, normalizeError = Schema.NormalizeArticle(options)
    if normalizeError then return nil, normalizeError end
    assignReporter(normalized)

    local signature, signatureError = Schema.BuildPublishSignature(normalized)
    if signatureError then return nil, signatureError end
    local existing = getStoredArticle(normalized.articleId)
    if existing then
        if existing.initialSignature == signature then
            local copy = defensiveCopy(existing)
            return copy, nil, false
        end
        addRepair("article_conflict", {articleId = normalized.articleId, publisherId = normalized.publisherId})
        return nil, "article_conflict"
    end

    local tombstone = self.record.tombstones[normalized.articleId]
    if tombstone then
        if tombstone.initialSignature == signature then return nil, "not_found", false end
        addRepair("article_conflict", {articleId = normalized.articleId, publisherId = normalized.publisherId, tombstoned = true})
        return nil, "article_conflict"
    end

    local now = serverTime()
    normalized.sequence = self.record.nextSequence
    self.record.nextSequence = self.record.nextSequence + 1
    normalized.revision = 0
    normalized.publishedAt = now
    normalized.updatedAt = now
    normalized.resolvedAt = nil
    normalized.outcome = nil
    normalized.initialSignature = signature
    self.record.active[normalized.articleId] = normalized
    queueNotification(normalized.articleId, "published")

    local copy = defensiveCopy(normalized)
    return copy, nil, true
end

function CosmicVaultNewsServer.updateArticle(articleId, publisherId, expectedRevision, patch)
    if not onServer() then return nil, "server_only" end
    ensureRuntimeRecord()
    if not Schema.IsIdentifier(articleId, Schema.LIMITS.articleId) or not Schema.IsIdentifier(publisherId, Schema.LIMITS.publisherId) then return nil, "invalid_id" end
    if type(expectedRevision) ~= "number" or expectedRevision % 1 ~= 0 then return nil, "invalid_arguments" end

    local current, collection = getStoredArticle(articleId)
    if not current then return nil, "not_found" end
    if current.publisherId ~= publisherId then return nil, "wrong_publisher" end
    if current.revision ~= expectedRevision then return nil, "stale_revision" end
    if collection ~= "active" or current.state ~= "active" then return nil, "invalid_state" end

    local updated, updateError = Schema.NormalizePatch(patch, current)
    if updateError then return nil, updateError end
    updated.initialSignature = current.initialSignature
    updated.revision = current.revision + 1
    updated.updatedAt = serverTime()
    self.record.active[articleId] = updated
    queueNotification(articleId, "updated")
    return defensiveCopy(updated)
end

function CosmicVaultNewsServer.resolveArticle(articleId, publisherId, expectedRevision, resolution)
    if not onServer() then return nil, "server_only" end
    ensureRuntimeRecord()
    if not Schema.IsIdentifier(articleId, Schema.LIMITS.articleId) or not Schema.IsIdentifier(publisherId, Schema.LIMITS.publisherId) then return nil, "invalid_id" end
    if type(expectedRevision) ~= "number" or expectedRevision % 1 ~= 0 then return nil, "invalid_arguments" end

    local current, collection = getStoredArticle(articleId)
    if not current then return nil, "not_found" end
    if current.publisherId ~= publisherId then return nil, "wrong_publisher" end
    if current.revision ~= expectedRevision then return nil, "stale_revision" end
    if collection ~= "active" or current.state ~= "active" then return nil, "invalid_state" end

    local normalized, normalizeError = Schema.NormalizeResolution(resolution)
    if normalizeError then return nil, normalizeError end
    local now = serverTime()
    current.state = normalized.state
    current.outcome = normalized.outcome
    current.revision = current.revision + 1
    current.updatedAt = now
    current.resolvedAt = now
    archiveArticle(current, normalized.state == "resolved" and "resolved" or normalized.state)
    return defensiveCopy(current)
end

function CosmicVaultNewsServer.getArticle(articleId, options)
    if not onServer() then return nil, "server_only" end
    ensureRuntimeRecord()
    if not Schema.IsIdentifier(articleId, Schema.LIMITS.articleId) then return nil, "invalid_id" end
    options = options or {}
    if type(options) ~= "table" then return nil, "invalid_arguments" end
    local article = getStoredArticle(articleId)
    if not article then return nil, "not_found" end
    if not isAudienceVisible(article, options.audiencePlayerIndex) then return nil, "not_found" end
    local copy, copyError = defensiveCopy(article)
    if not copy then return nil, copyError end
    copy.ageSeconds = math.max(0, serverTime() - (copy.publishedAt or 0))
    return copy, nil
end

function CosmicVaultNewsServer.query(options)
    if not onServer() then return nil, "server_only" end
    ensureRuntimeRecord()
    local query, queryError = normalizeQuery(options)
    if queryError then return nil, queryError end
    if query.ifRevision == self.record.feedRevision and not query.beforeSequence then return nil, "not_modified" end

    local matches = {}
    for _, article in pairs(self.record.active) do
        if matchesQuery(article, query) then matches[#matches + 1] = article end
    end
    if query.includeArchive then
        for _, article in pairs(self.record.archive) do
            if matchesQuery(article, query) then matches[#matches + 1] = article end
        end
    end
    table.sort(matches, function(left, right) return left.sequence > right.sequence end)

    local items = {}
    local now = serverTime()
    local take = math.min(#matches, query.pageSize)
    for index = 1, take do
        local copy, copyError = defensiveCopy(matches[index])
        if not copy then return nil, copyError end
        copy.ageSeconds = math.max(0, now - (copy.publishedAt or 0))
        items[#items + 1] = copy
    end

    local nextCursor
    if #items > 0 and #matches > #items then nextCursor = items[#items].sequence end
    return {
        schemaVersion = Schema.ARTICLE_SCHEMA_VERSION,
        feedRevision = self.record.feedRevision,
        latestSequence = self.record.nextSequence - 1,
        items = items,
        nextCursor = nextCursor,
        hasMore = #matches > #items,
    }, nil
end

function CosmicVaultNewsServer.getSnapshot()
    if not onServer() then return nil, "server_only" end
    ensureRuntimeRecord()
    local openRepairs = 0
    for _, finding in ipairs(self.record.repairFindings) do
        if finding.state == "open" then openRepairs = openRepairs + 1 end
    end
    return {
        schemaVersion = Schema.MANAGER_SCHEMA_VERSION,
        revision = self.record.revision,
        feedRevision = self.record.feedRevision,
        latestSequence = self.record.nextSequence - 1,
        activeCount = tableCount(self.record.active),
        archiveCount = tableCount(self.record.archive),
        publisherCount = tableCount(self.record.publishers),
        tombstoneCount = tableCount(self.record.tombstones),
        openRepairCount = openRepairs,
        migration = {
            state = self.record.migration.state,
            version = self.record.migration.version,
            imported = self.record.migration.imported,
            lastError = self.record.migration.lastError,
        },
        health = self.record.lastError and "degraded" or "healthy",
        lastError = self.record.lastError,
    }, nil
end

local function publishLegacy(article, identityPrefix)
    if type(article) ~= "table" then return nil, "invalid_arguments" end
    local identityText = tostring(article.timestamp or serverTime()) .. "|" .. tostring(article.title or "") .. "|" .. tostring(self.record.nextSequence)
    local hash = Schema.StableHash(identityText)
    local eventId = identityPrefix .. ":" .. tostring(hash) .. ":" .. tostring(self.record.nextSequence)
    local normalized, normalizeError = Schema.NormalizeLegacyArticle(article, eventId)
    if normalizeError then return nil, normalizeError end
    return CosmicVaultNewsServer.publish(normalized)
end

-- Compatibility entry point for code that included this manager directly.
function CosmicVaultNewsServer.publishArticle(article)
    if not onServer() then return nil, "server_only" end
    ensureRuntimeRecord()
    return publishLegacy(article, "legacy:direct")
end

function CosmicVaultNewsServer.getNews()
    if not onServer() then return {} end
    ensureRuntimeRecord()
    local page = CosmicVaultNewsServer.query({pageSize = 30, includeArchive = true})
    if type(page) ~= "table" then return {} end
    local legacy = {}
    for _, article in ipairs(page.items) do
        legacy[#legacy + 1] = {
            title = article.title,
            content = article.content,
            category = article.category,
            breaking = article.breaking,
            author = article.author,
            timestamp = article.publishedAt,
        }
    end
    return legacy
end

function CosmicVaultNewsServer.onSyncRequest(playerIndex)
    if not onServer() then return end
    ensureRuntimeRecord()
    if tableCount(self.record.active) + tableCount(self.record.archive) == 0 then
        debugInfo("News store is empty; requesting compatibility seeds for player %s.", tostring(playerIndex))
        Server():sendCallback("onCCNewsRequestSeed")
    end
end

function CosmicVaultNewsServer.onPublishArticle(article)
    if not onServer() then return end
    ensureRuntimeRecord()
    local _, err = publishLegacy(article, "legacy:callback")
    if err then debugError("Rejected legacy callback article: %s", tostring(err)) end
end

function CosmicVaultNewsServer.secure()
    ensureRuntimeRecord()
    local record = defensiveCopy(self.record)
    return {
        newsV2 = record or newRecord(),
        publishedNews = self.record.migration.legacyV1 or CosmicVaultNewsServer.getNews(),
    }
end

function CosmicVaultNewsServer.restore(data)
    self.pendingNotifications = {}
    if type(data) == "table" and ensureRecordShape(data.newsV2) then
        local copy, copyError = defensiveCopy(data.newsV2)
        if copy then
            self.record = copy
            registerCanonicalPublishers()
            return
        end
        debugError("News v2 restore failed: %s", tostring(copyError))
    end

    local legacy = type(data) == "table" and type(data.publishedNews) == "table" and data.publishedNews or {}
    importLegacy(legacy)
end

function CosmicVaultNewsServer.getUpdateInterval()
    return 1.0
end

function CosmicVaultNewsServer.updateServer(timeStep)
    if not onServer() or not self.record then return end
    local expired = expireActive(MAINTENANCE_BATCH)
    enforceBounds(math.max(0, MAINTENANCE_BATCH - expired))

    local notifications = self.pendingNotifications
    self.pendingNotifications = {}
    for _, notification in ipairs(notifications) do
        Server():sendCallback("onCosmicVaultNewsChanged", notification.feedRevision, notification.articleId, notification.changeType)
    end
end

return CosmicVaultNewsServer
