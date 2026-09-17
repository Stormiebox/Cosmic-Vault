include("randomext")
include("stringutility")

-- namespace CosmicVaultRiftEscalation
CosmicVaultRiftEscalation = {}

local CosmicVaultData = include("cosmicvaultdata")
local CosmicVaultNewsAdapter = include("cosmicvaultnewsadapter")

local RECORD_KEY = "cv_rift_escalation_v1"
local SCHEMA_VERSION = 1
local ATTACK_SCRIPT = "data/scripts/player/events/alienattack.lua"
local MAX_ATTEMPTS = 5
local REPLAY_WINDOW = 10 * 60
local RECEIPT_LIFETIME = 30 * 24 * 60 * 60
local RECEIPT_CAP = 4096

local state
local storageError

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
    for key, item in pairs(value) do copy[deepCopy(key, seen)] = deepCopy(item, seen) end
    return copy
end

local function calculateEscalation(record)
    return math.max(0, tonumber(record.guardianKills) or 0)
        + math.max(0, tonumber(record.deepExtractions) or 0) * 0.5
end

local function newState()
    return {
        schemaVersion = SCHEMA_VERSION,
        revision = 0,
        guardianKills = 0,
        deepExtractions = 0,
        escalation = 0,
        processedEvents = {},
        lastExtractionByPlayer = {},
        migrationProvenance = {}
    }
end

local function validState(record)
    if not (type(record) == "table" and record.schemaVersion == SCHEMA_VERSION
        and type(record.revision) == "number"
        and type(record.guardianKills) == "number"
        and type(record.deepExtractions) == "number"
        and type(record.processedEvents) == "table"
        and type(record.lastExtractionByPlayer) == "table"
        and type(record.migrationProvenance) == "table") then
        return false
    end
    for eventId, receipt in pairs(record.processedEvents) do
        if type(eventId) ~= "string" or type(receipt) ~= "table"
                or receipt.eventId ~= eventId or receipt.state ~= "completed"
                or type(receipt.completedAt) ~= "number" then
            return false
        end
    end
    for playerKey, extraction in pairs(record.lastExtractionByPlayer) do
        if type(playerKey) ~= "string" or type(extraction) ~= "table"
                or type(extraction.fingerprint) ~= "string"
                or type(extraction.acceptedAt) ~= "number"
                or type(extraction.receipt) ~= "table" then
            return false
        end
    end
    if record.dispatch ~= nil then
        local dispatchStates = {
            prepared = true, materializing = true, verifying = true,
            retryable = true, completed = true, repair_required = true
        }
        local dispatch = record.dispatch
        if type(dispatch) ~= "table" or dispatch.schemaVersion ~= 1
                or type(dispatch.revision) ~= "number"
                or type(dispatch.dispatchId) ~= "string"
                or not dispatchStates[dispatch.state]
                or type(dispatch.attempts) ~= "number"
                or type(dispatch.targets) ~= "table"
                or type(dispatch.createdAt) ~= "number"
                or type(dispatch.updatedAt) ~= "number" then
            return false
        end
        for _, target in ipairs(dispatch.targets) do
            if type(target) ~= "table" or type(target.playerIndex) ~= "number"
                    or type(target.attackType) ~= "number" then
                return false
            end
        end
    end
    return true
end

local function loadState()
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
    if not validState(loaded) then
        storageError = "corrupt"
        return nil, storageError
    end
    state = loaded
    state.escalation = calculateEscalation(state)
    return true, nil
end

local function mirrorLegacy()
    local server = Server()
    server:setValue("cv_rift_guardian_kills", state.guardianKills)
    server:setValue("cv_rift_extractions", state.deepExtractions)
end

local function persist(working)
    working.escalation = calculateEscalation(working)
    working.revision = (state and state.revision or working.revision or 0) + 1
    local ok, err = CosmicVaultData.SetRecord(Server(), RECORD_KEY, working)
    if not ok then
        working.lastError = tostring(err or "write_failed")
        return nil, "persistence_failure"
    end
    state = working
    mirrorLegacy()
    return true, nil
end

local function migrateLegacy()
    local available, err = loadState()
    if not available then return nil, err end
    if state.migrationProvenance.legacyCounters then return true, nil end

    local server = Server()
    local legacyKills = server:getValue("cv_rift_guardian_kills")
    local legacyExtractions = server:getValue("cv_rift_extractions")
    legacyKills = type(legacyKills) == "number" and math.max(0, legacyKills) or 0
    legacyExtractions = type(legacyExtractions) == "number" and math.max(0, legacyExtractions) or 0

    local working = deepCopy(state)
    working.guardianKills = math.max(working.guardianKills, legacyKills)
    working.deepExtractions = math.max(working.deepExtractions, legacyExtractions)
    working.migrationProvenance.legacyCounters = {
        importedAt = now(),
        guardianKills = legacyKills,
        deepExtractions = legacyExtractions
    }
    return persist(working)
end

local function ensureReady()
    local available, err = loadState()
    if not available then return nil, err end
    if not state.migrationProvenance.legacyCounters then return migrateLegacy() end
    return true, nil
end

local function pruneReceipts(working, currentTime)
    local retained = {}
    for id, receipt in pairs(working.processedEvents) do
        if type(receipt.completedAt) ~= "number" or currentTime - receipt.completedAt < RECEIPT_LIFETIME then
            table.insert(retained, {id = id, receipt = receipt})
        end
    end
    table.sort(retained, function(left, right)
        return (left.receipt.completedAt or 0) > (right.receipt.completedAt or 0)
    end)
    working.processedEvents = {}
    for index = 1, math.min(#retained, RECEIPT_CAP) do
        local item = retained[index]
        working.processedEvents[item.id] = item.receipt
    end
end

local function newsLocation(evidence)
    if type(evidence) == "table" and type(evidence.x) == "number" and type(evidence.y) == "number" then
        return {x = evidence.x, y = evidence.y, radius = 12}
    end
end

local function publishEscalationEvent(kind, receipt)
    local eventId = CosmicVaultNewsAdapter.StableId("rift-escalation", receipt.eventId)
    if not eventId then return end
    local guardian = kind == "guardian"
    local location = newsLocation(receipt.evidence)
    CosmicVaultNewsAdapter.Upsert({
        eventId = eventId,
        threadId = "rift:escalation",
        eventType = guardian and "rift.escalation.guardian_destroyed" or "rift.escalation.deep_extraction",
        topic = "rift",
        category = "Rift",
        severity = guardian and "critical" or "warning",
        breaking = guardian,
        title = guardian and "Rift Guardian Down" or "Deep Rift Extraction",
        content = (guardian and "A Rift Guardian has been destroyed." or "A deep Rift extraction succeeded.")
            .. " Global Rift Escalation: " .. tostring(state.escalation),
        author = "Cosmic Vault",
        location = location,
        audience = location and {mode = "region"} or {mode = "galaxy"},
        lead = location and {kind = "location", x = location.x, y = location.y} or nil,
        provenance = {
            recordType = RECORD_KEY,
            sourceEventId = tostring(receipt.eventId),
            sourceRevision = state.revision or 0,
            sourceState = tostring(receipt.state),
            escalation = state.escalation,
        },
    })
end

local function publishDispatch(dispatch)
    if type(dispatch) ~= "table" then return end
    local eventId = CosmicVaultNewsAdapter.StableId("rift-retaliation", dispatch.dispatchId)
    if not eventId then return end
    local verifiedCount = 0
    for _ in pairs(dispatch.verifiedTargets or {}) do verifiedCount = verifiedCount + 1 end
    local article = CosmicVaultNewsAdapter.Upsert({
        eventId = eventId,
        threadId = eventId,
        eventType = "rift.retaliation.lifecycle",
        topic = "rift",
        category = "Crisis",
        severity = dispatch.state == "completed" and "critical" or "warning",
        breaking = dispatch.state == "completed",
        title = "Global Rift Retaliation",
        content = dispatch.state == "completed"
            and ("Xsotan retaliation was verified against " .. tostring(verifiedCount) .. " commanders.")
            or ("Rift retaliation state: " .. tostring(dispatch.state) .. "."),
        author = "Cosmic Vault",
        audience = {mode = "galaxy"},
        provenance = {
            recordType = RECORD_KEY,
            dispatchId = tostring(dispatch.dispatchId),
            sourceRevision = dispatch.revision or 0,
            sourceState = tostring(dispatch.state),
            attempts = dispatch.attempts or 0,
            verifiedTargets = verifiedCount,
        },
    })
    if article and dispatch.state == "completed" then
        CosmicVaultNewsAdapter.Resolve(eventId,
            "Retaliation dispatch verified for " .. tostring(verifiedCount) .. " commanders.")
    end
end

local function announceEvent(kind, receipt)
    local level = state.escalation
    if kind == "guardian" then
        Server():broadcastChatMessage("System"%_T, ChatMessageType.Warning,
            "WARNING: A Rift Guardian has been destroyed. Global Rift Escalation: %1%"%_T,
            tostring(level))
    else
        Server():broadcastChatMessage("System"%_T, ChatMessageType.Warning,
            "WARNING: A deep Rift extraction succeeded. Global Rift Escalation: %1%"%_T,
            tostring(level))
    end
    publishEscalationEvent(kind, receipt)
end

local function acceptEvent(eventId, kind, evidence)
    local existing = state.processedEvents[eventId]
    if existing then
        publishEscalationEvent(kind, existing)
        return deepCopy(existing), nil
    end

    local working = deepCopy(state)
    if kind == "guardian" then
        working.guardianKills = working.guardianKills + 1
    else
        working.deepExtractions = working.deepExtractions + 1
    end
    local receipt = {
        schemaVersion = 1,
        eventId = eventId,
        kind = kind,
        evidence = deepCopy(evidence),
        state = "completed",
        completedAt = now()
    }
    working.processedEvents[eventId] = receipt
    pruneReceipts(working, now())
    local saved, saveError = persist(working)
    if not saved then return nil, saveError end
    announceEvent(kind, receipt)
    return deepCopy(receipt), nil
end

function CosmicVaultRiftEscalation.initialize()
    if not onServer() then return end
    local ready = ensureReady()
    if ready and state.dispatch and state.dispatch.state == "materializing" then
        local working = deepCopy(state)
        working.dispatch.state = "repair_required"
        working.dispatch.revision = (working.dispatch.revision or 0) + 1
        working.dispatch.updatedAt = now()
        working.dispatch.lastError = "interrupted_materialization"
        working.dispatch.repairRequired = "dispatch_side_effect_ambiguous"
        working.repairRequired = "rift_dispatch_requires_repair"
        local saved = persist(working)
        if saved then publishDispatch(state.dispatch) end
    end
end

function CosmicVaultRiftEscalation.reportGuardianDestroyed(eventId, evidence)
    local ready, err = ensureReady()
    if not ready then return nil, err end
    if type(eventId) ~= "string" or eventId == "" or type(evidence) ~= "table"
            or type(evidence.entityUuid) ~= "string" or evidence.entityUuid == "" then
        return nil, "invalid_arguments"
    end
    local canonicalId = "guardian:" .. evidence.entityUuid
    if eventId ~= canonicalId then return nil, "event_id_mismatch" end
    return acceptEvent(canonicalId, "guardian", evidence)
end

function CosmicVaultRiftEscalation.reportDeepExtraction(eventId, evidence)
    local ready, err = ensureReady()
    if not ready then return nil, err end
    if type(eventId) ~= "string" or eventId == "" or type(evidence) ~= "table"
            or type(evidence.playerIndex) ~= "number" or type(evidence.riftDepth) ~= "number"
            or type(evidence.sectorSeed) ~= "string" then
        return nil, "invalid_arguments"
    end
    if evidence.riftDepth < 50 then return nil, "not_qualifying" end

    local playerKey = tostring(evidence.playerIndex)
    local fingerprint = playerKey .. ":" .. evidence.sectorSeed .. ":" .. tostring(evidence.riftDepth)
    if eventId ~= "extraction:" .. fingerprint then return nil, "event_id_mismatch" end
    local existing = state.processedEvents[eventId]
    if existing then
        publishEscalationEvent("extraction", existing)
        return deepCopy(existing), nil
    end

    local last = state.lastExtractionByPlayer[playerKey]
    if last and last.fingerprint == fingerprint then
        if now() - (last.acceptedAt or 0) <= REPLAY_WINDOW then
            publishEscalationEvent("extraction", last.receipt)
            return deepCopy(last.receipt), nil
        end
        local working = deepCopy(state)
        working.repairRequired = "ambiguous_deep_extraction:" .. fingerprint
        working.lastError = "A repeated extraction fingerprint arrived outside the replay window."
        persist(working)
        return nil, "ambiguous_evidence"
    end

    local working = deepCopy(state)
    working.deepExtractions = working.deepExtractions + 1
    local receipt = {
        schemaVersion = 1,
        eventId = eventId,
        kind = "deep_extraction",
        evidence = deepCopy(evidence),
        state = "completed",
        completedAt = now()
    }
    working.processedEvents[eventId] = receipt
    working.lastExtractionByPlayer[playerKey] = {
        fingerprint = fingerprint,
        acceptedAt = now(),
        receipt = deepCopy(receipt)
    }
    pruneReceipts(working, now())
    local saved, saveError = persist(working)
    if not saved then return nil, saveError end
    announceEvent("extraction", receipt)
    return deepCopy(receipt), nil
end

function CosmicVaultRiftEscalation.getEscalationSnapshot()
    local ready, err = ensureReady()
    if not ready then return nil, err end
    return deepCopy(state), nil
end

local function eligibleTargets()
    local targets = {}
    for _, player in pairs({Server():getOnlinePlayers()}) do
        if not player:hasScript(ATTACK_SCRIPT) then
            table.insert(targets, {
                playerIndex = player.index,
                attackType = random():getInt(0, 2)
            })
        end
    end
    table.sort(targets, function(left, right) return left.playerIndex < right.playerIndex end)
    return targets
end

local function prepareDispatch()
    if state.dispatch then return false end
    if state.escalation <= 10 then return false end
    local chance = math.min(0.5, (state.escalation - 10) * 0.05)
    if not random():test(chance) then return false end
    local targets = eligibleTargets()
    if #targets == 0 then return false end

    local working = deepCopy(state)
    working.dispatch = {
        schemaVersion = 1,
        revision = 1,
        dispatchId = "rift-swarm:" .. tostring(state.revision + 1) .. ":" .. tostring(math.floor(now())),
        state = "prepared",
        attempts = 0,
        targets = targets,
        createdAt = now(),
        updatedAt = now(),
        nextAttemptAt = now()
    }
    local saved, saveError = persist(working)
    if saved then publishDispatch(state.dispatch) end
    return saved, saveError
end

local function materializeDispatch()
    local dispatch = state.dispatch
    if not dispatch or (dispatch.state ~= "prepared" and dispatch.state ~= "retryable") then return end
    if type(dispatch.nextAttemptAt) == "number" and dispatch.nextAttemptAt > now() then return end

    local working = deepCopy(state)
    working.dispatch.state = "materializing"
    working.dispatch.attempts = (working.dispatch.attempts or 0) + 1
    working.dispatch.revision = (working.dispatch.revision or 0) + 1
    working.dispatch.updatedAt = now()
    local saved = persist(working)
    if not saved then return end

    local attempted = {}
    for _, target in ipairs(state.dispatch.targets) do
        local player = Player(target.playerIndex)
        if player then
            if not player:hasScript(ATTACK_SCRIPT) then
                player:addScriptOnce(ATTACK_SCRIPT, target.attackType)
            end
            attempted[tostring(target.playerIndex)] = true
        end
    end

    working = deepCopy(state)
    working.dispatch.state = "verifying"
    working.dispatch.revision = working.dispatch.revision + 1
    working.dispatch.updatedAt = now()
    working.dispatch.attemptedTargets = attempted
    persist(working)
end

local function verifyDispatch()
    local dispatch = state.dispatch
    if not dispatch or dispatch.state ~= "verifying" then return end
    local verified = {}
    for _, target in ipairs(dispatch.targets) do
        local player = Player(target.playerIndex)
        if player and player:hasScript(ATTACK_SCRIPT) then
            verified[tostring(target.playerIndex)] = true
        end
    end

    local verifiedCount = 0
    for _ in pairs(verified) do verifiedCount = verifiedCount + 1 end
    local working = deepCopy(state)
    if verifiedCount == 0 then
        working.dispatch.revision = working.dispatch.revision + 1
        working.dispatch.updatedAt = now()
        working.dispatch.lastError = "no_attack_attachment_verified"
        if working.dispatch.attempts >= MAX_ATTEMPTS then
            working.dispatch.state = "repair_required"
            working.dispatch.repairRequired = "automatic_attempts_exhausted"
            working.repairRequired = "rift_dispatch_requires_repair"
        else
            working.dispatch.state = "retryable"
            working.dispatch.nextAttemptAt = now() + 60 * working.dispatch.attempts
        end
        local saved = persist(working)
        if saved then publishDispatch(state.dispatch) end
        return
    end

    working.dispatch.state = "completed"
    working.dispatch.revision = working.dispatch.revision + 1
    working.dispatch.updatedAt = now()
    working.dispatch.completedAt = now()
    working.dispatch.verifiedTargets = verified
    working.guardianKills = math.max(0, working.guardianKills - 2)
    working.deepExtractions = math.max(0, working.deepExtractions - 2)
    working.processedEvents[working.dispatch.dispatchId] = {
        schemaVersion = 1,
        eventId = working.dispatch.dispatchId,
        kind = "rift_swarm",
        state = "completed",
        targets = deepCopy(verified),
        completedAt = now()
    }
    pruneReceipts(working, now())
    local saved = persist(working)
    if not saved then return end

    Server():broadcastChatMessage("System"%_T, ChatMessageType.Warning,
        "CRITICAL: Global Rift Escalation Threshold Reached. Xsotan swarms converging galaxy-wide!"%_T)
    publishDispatch(state.dispatch)
end

function CosmicVaultRiftEscalation.getUpdateInterval()
    return 60
end

function CosmicVaultRiftEscalation.updateServer(timeStep)
    local ready = ensureReady()
    if not ready then return end
    if state.dispatch and state.dispatch.state == "completed" then
        local working = deepCopy(state)
        working.dispatch = nil
        persist(working)
        return
    end
    if not state.dispatch then
        prepareDispatch()
        return
    end
    if state.dispatch.state == "prepared" or state.dispatch.state == "retryable" then
        materializeDispatch()
        return
    end
    if state.dispatch.state == "verifying" then verifyDispatch() end
end
