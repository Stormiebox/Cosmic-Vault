local Schema = include("cosmicvaultdialogue_schema")
local NewsSchema = include("cosmicvaultnews_schema")
local Debug = include("cosmicvaultdebug")

-- namespace CosmicVaultDialogueServer
CosmicVaultDialogueServer = {}
local self = CosmicVaultDialogueServer

local REPAIR_LIMIT = 128

self.record = nil

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
        catalogRevision = 0,
        publishers = {},
        entries = {},
        repairFindings = {},
        nextRepairId = 1,
        lastError = nil,
    }
end

local function validRecord(record)
    if type(record) ~= "table" or record.schemaVersion ~= Schema.MANAGER_SCHEMA_VERSION then return false end
    if type(record.revision) ~= "number" or type(record.catalogRevision) ~= "number" then return false end
    if type(record.publishers) ~= "table" or type(record.entries) ~= "table" or type(record.repairFindings) ~= "table" then return false end
    record.nextRepairId = tonumber(record.nextRepairId) or 1
    return true
end

local function defensiveCopy(value)
    local copy, err = Schema.DeepCopy(value)
    if err then return nil, "corrupt_record" end
    return copy, nil
end

local function addRepair(kind, evidence)
    local repairId = "dialogue:" .. tostring(self.record.nextRepairId)
    self.record.nextRepairId = self.record.nextRepairId + 1
    local copiedEvidence = Schema.DeepCopy(evidence or {})
    self.record.repairFindings[#self.record.repairFindings + 1] = {
        schemaVersion = 1,
        repairId = repairId,
        kind = kind,
        state = "open",
        createdAt = serverTime(),
        evidence = copiedEvidence or {},
    }
    while #self.record.repairFindings > REPAIR_LIMIT do table.remove(self.record.repairFindings, 1) end
    self.record.revision = self.record.revision + 1
end

local function debugError(message, ...)
    if Debug and Debug.error then Debug.error("CosmicVaultDialogue", message, ...) end
end

local function registerPublisherInternal(definition)
    local normalized, normalizeError = Schema.NormalizePublisher(definition)
    if normalizeError then return nil, normalizeError end
    local existing = self.record.publishers[normalized.publisherId]
    if existing then
        if NewsSchema.DeepEqual(existing, normalized) then
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
    local definitions = NewsSchema.GetCanonicalPublishers()
    local ids = {"cosmic_vault", "cosmic_war", "cosmic_overhaul", "cosmic_chronicles", "cosmic_ascendancy"}
    for _, publisherId in ipairs(ids) do
        local _, err = registerPublisherInternal(definitions[publisherId])
        if err then debugError("Canonical publisher %s could not be registered: %s", publisherId, err) end
    end
end

function CosmicVaultDialogueServer.initialize()
    if not onServer() then return end
    if not self.record then self.record = newRecord() end
    registerCanonicalPublishers()
end

function CosmicVaultDialogueServer.registerPublisher(definition)
    if not onServer() then return nil, "server_only" end
    return registerPublisherInternal(definition)
end

function CosmicVaultDialogueServer.registerEntries(publisherId, entries)
    if not onServer() then return nil, "server_only" end
    if type(publisherId) ~= "string" or not self.record.publishers[publisherId] then return nil, "not_found" end
    if type(entries) ~= "table" or #entries < 1 or #entries > Schema.LIMITS.entriesPerCall then return nil, "invalid_arguments" end

    local normalizedEntries = {}
    local batchIds = {}
    for _, entry in ipairs(entries) do
        local normalized, normalizeError = Schema.NormalizeEntry(publisherId, entry)
        if normalizeError then return nil, normalizeError end
        if batchIds[normalized.lineId] and not NewsSchema.DeepEqual(batchIds[normalized.lineId], normalized) then
            addRepair("line_conflict", {lineId = normalized.lineId, publisherId = publisherId, source = "batch"})
            return nil, "line_conflict"
        end
        if not batchIds[normalized.lineId] then
            batchIds[normalized.lineId] = normalized
            normalizedEntries[#normalizedEntries + 1] = normalized
        end
    end

    local newCount = 0
    for _, entry in ipairs(normalizedEntries) do
        local existing = self.record.entries[entry.lineId]
        if existing and not NewsSchema.DeepEqual(existing, entry) then
            addRepair("line_conflict", {lineId = entry.lineId, publisherId = publisherId, source = "catalog"})
            return nil, "line_conflict"
        end
        if not existing then newCount = newCount + 1 end
    end
    if tableCount(self.record.entries) + newCount > Schema.LIMITS.catalogEntries then return nil, "storage_failed" end

    for _, entry in ipairs(normalizedEntries) do self.record.entries[entry.lineId] = entry end
    if newCount > 0 then
        self.record.catalogRevision = self.record.catalogRevision + 1
        self.record.revision = self.record.revision + 1
    end
    return {
        schemaVersion = Schema.MANAGER_SCHEMA_VERSION,
        catalogRevision = self.record.catalogRevision,
        registered = #normalizedEntries,
        created = newCount,
    }, nil, newCount > 0
end

function CosmicVaultDialogueServer.registerLegacyEntry(entry)
    if not onServer() then return nil, "server_only" end
    local normalized, normalizeError = Schema.NormalizeLegacyEntry(entry)
    if normalizeError then return nil, normalizeError end
    if not self.record.publishers[normalized.publisherId] then
        local displayName = type(entry.modId) == "string" and entry.modId or "Legacy Publisher"
        local shortName = displayName:gsub("[^%w]", ""):upper():sub(1, 16)
        if shortName == "" then shortName = "LEGACY" end
        local _, publisherError = registerPublisherInternal({
            schemaVersion = 1,
            publisherId = normalized.publisherId,
            displayName = displayName,
            shortName = shortName,
        })
        if publisherError then return nil, publisherError end
    end
    local _, registerError, created = CosmicVaultDialogueServer.registerEntries(normalized.publisherId, {normalized})
    if registerError then return nil, registerError end
    return defensiveCopy(normalized), nil, created
end

function CosmicVaultDialogueServer.getEntry(lineId)
    if not onServer() then return nil, "server_only" end
    if type(lineId) ~= "string" then return nil, "invalid_id" end
    local entry = self.record.entries[lineId]
    if not entry then return nil, "not_found" end
    return defensiveCopy(entry)
end

function CosmicVaultDialogueServer.query(category, context, options)
    if not onServer() then return nil, "server_only" end
    if type(category) ~= "string" or category == "" or #category > Schema.LIMITS.category then return nil, "invalid_category" end
    local normalizedContext, contextError = Schema.NormalizeContext(context)
    if contextError then return nil, contextError end
    options = options or {}
    if type(options) ~= "table" then return nil, "invalid_arguments" end
    local excludeIds, excludeError = Schema.NormalizeExcludeIds(options.excludeIds)
    if excludeError then return nil, excludeError end
    if options.seed ~= nil and type(options.seed) ~= "number" then return nil, "invalid_arguments" end

    local candidates = {}
    for lineId, entry in pairs(self.record.entries) do
        if entry.category == category and not excludeIds[lineId] then
            local matches, matchError = Schema.Matches(entry, normalizedContext)
            if matchError then return nil, matchError end
            if matches then candidates[#candidates + 1] = entry end
        end
    end
    table.sort(candidates, function(left, right) return left.lineId < right.lineId end)
    if #candidates == 0 then return nil, "not_found" end

    local seed = options.seed
    if seed == nil then seed = random():getInt(0, 2147483646) end
    local selected, selectionError = Schema.SelectWeighted(candidates, seed)
    if selectionError then return nil, selectionError end
    return {
        schemaVersion = Schema.ENTRY_SCHEMA_VERSION,
        catalogRevision = self.record.catalogRevision,
        candidateCount = math.min(#candidates, Schema.LIMITS.queryResults),
        entry = selected,
    }, nil
end

function CosmicVaultDialogueServer.getCatalogSnapshot()
    if not onServer() then return nil, "server_only" end
    local openRepairs = 0
    for _, finding in ipairs(self.record.repairFindings) do
        if finding.state == "open" then openRepairs = openRepairs + 1 end
    end
    return {
        schemaVersion = Schema.MANAGER_SCHEMA_VERSION,
        revision = self.record.revision,
        catalogRevision = self.record.catalogRevision,
        publisherCount = tableCount(self.record.publishers),
        entryCount = tableCount(self.record.entries),
        openRepairCount = openRepairs,
        health = self.record.lastError and "degraded" or "healthy",
        lastError = self.record.lastError,
    }, nil
end

function CosmicVaultDialogueServer.secure()
    local copy = defensiveCopy(self.record)
    return {dialogueV2 = copy or newRecord()}
end

function CosmicVaultDialogueServer.restore(data)
    if type(data) == "table" and validRecord(data.dialogueV2) then
        local copy, copyError = defensiveCopy(data.dialogueV2)
        if copy then
            self.record = copy
            registerCanonicalPublishers()
            return
        end
        debugError("Dialogue v2 restore failed: %s", tostring(copyError))
    end

    self.record = newRecord()
    registerCanonicalPublishers()
    if data ~= nil then
        self.record.lastError = "corrupt_record"
        addRepair("corrupt_restore", {reason = "unsupported_or_corrupt_envelope"})
    end
end

return CosmicVaultDialogueServer
