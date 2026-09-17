
include("stringutility")

local CosmicVaultTerritory = {}
local CosmicVaultData = include("cosmicvaultdata")
local CosmicVaultNewsAdapter = include("cosmicvaultnewsadapter")

-- This API handles background sieges and contested zones for Cosmic War and other expansions.
-- It avoids loading 1,000 sectors to simulate combat, instead mathematically conquering sectors.

if onServer() then

    local KIND_REGISTRY_KEY = "cv_materialization_v1_kinds"
    local knownKinds = {flip = true, expansion = true, annihilation = true, siege = true}
    local MAX_ATTEMPTS = 5
    local TOMBSTONE_LIFETIME = 7 * 24 * 60 * 60

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

    local function validKind(kind)
        return type(kind) == "string" and kind ~= "" and string.match(kind, "^[%w_%-]+$") ~= nil
    end

    local function validCoordinate(value)
        return type(value) == "number" and value == math.floor(value)
    end

    local function coordinateKey(x, y)
        return tostring(x) .. ":" .. tostring(y)
    end

    local function operationId(record)
        return record.id .. ":" .. tostring(record.createdAt or 0)
    end

    local function publishCompletedMaterialization(record)
        if record.kind ~= "flip" and record.kind ~= "expansion" then return end
        local factionIndex = record.result and record.result.controllingFactionIndex
            or record.payload and record.payload.factionIndex
        if type(factionIndex) ~= "number" then return end
        local faction = Faction(factionIndex)
        local factionName = faction and faction.name or "an unknown faction"
        local eventId = CosmicVaultNewsAdapter.StableId("territory", operationId(record))
        if not eventId then return end
        local isExpansion = record.kind == "expansion"
        CosmicVaultNewsAdapter.Upsert({
            eventId = eventId,
            threadId = "territory:" .. tostring(record.x) .. ":" .. tostring(record.y),
            eventType = isExpansion and "territory.expansion.completed" or "territory.flip.completed",
            topic = "politics",
            category = isExpansion and "Politics" or "War",
            severity = isExpansion and "info" or "warning",
            title = isExpansion and "Galactic Borders Shift" or "Territory Conquered",
            content = "Sector [\\s(" .. tostring(record.x) .. ":" .. tostring(record.y)
                .. ")] is now under the verified control of " .. tostring(factionName) .. ".",
            author = "Cosmic Vault",
            location = {x = record.x, y = record.y, radius = 0},
            audience = {mode = "galaxy"},
            lead = {kind = "location", x = record.x, y = record.y},
            provenance = {
                recordType = "cv_materialization_v1_" .. record.kind,
                operationId = operationId(record),
                sourceRevision = record.revision or 0,
                controllingFaction = factionIndex,
                verified = record.result and record.result.verified == true or nil,
            },
        })
    end

    local function queueStorageKey(kind)
        return "cv_materialization_v1_" .. kind
    end

    local function loadKindRegistry()
        local registry, err = CosmicVaultData.GetRecord(Server(), KIND_REGISTRY_KEY, 1)
        if not registry and err == "missing" then
            return {schemaVersion = 1, revision = 0, kinds = deepCopy(knownKinds)}, nil
        end
        if not registry then return nil, err end
        if type(registry.revision) ~= "number" or type(registry.kinds) ~= "table" then
            return nil, "corrupt"
        end
        return registry, nil
    end

    local function rememberKind(kind)
        local registry, err = loadKindRegistry()
        local rebuilt = false
        if not registry and (err == "corrupt" or err == "unsupported_version") then
            -- This is a derived pruning index, not authoritative queued work. Rebuild it
            -- from the fixed public kinds plus the kind currently being accessed.
            registry = {schemaVersion = 1, revision = 0, kinds = deepCopy(knownKinds)}
            rebuilt = true
        elseif not registry then
            return nil, err
        end
        if registry.kinds[kind] == true and not rebuilt then return true, nil end

        registry = deepCopy(registry)
        registry.kinds[kind] = true
        registry.revision = registry.revision + 1
        return CosmicVaultData.SetRecord(Server(), KIND_REGISTRY_KEY, registry)
    end

    local function loadQueue(kind)
        if not validKind(kind) then return nil, "invalid_kind" end
        local remembered, rememberError = rememberKind(kind)
        if not remembered then return nil, rememberError end
        local queue, err = CosmicVaultData.GetRecord(Server(), queueStorageKey(kind), 1)
        if not queue and err == "missing" then
            queue = {schemaVersion = 1, revision = 0, entries = {}}
        elseif not queue then
            return nil, err
        end

        if type(queue.revision) ~= "number" or type(queue.entries) ~= "table" then
            return nil, "corrupt"
        end

        return queue, nil
    end

    local function saveQueue(kind, queue)
        queue.revision = (queue.revision or 0) + 1
        local ok, err = CosmicVaultData.SetRecord(Server(), queueStorageKey(kind), queue)
        if not ok then
            queue.revision = math.max(0, queue.revision - 1)
            return nil, err
        end
        return true, nil
    end

    local function getEntry(kind, x, y)
        if not validCoordinate(x) or not validCoordinate(y) then return nil, "invalid_coordinate" end
        local queue, err = loadQueue(kind)
        if not queue then return nil, err end
        return queue.entries[coordinateKey(x, y)], nil, queue
    end

    function CosmicVaultTerritory.QueueMaterialization(kind, x, y, payload)
        if not validKind(kind) then return nil, "invalid_kind" end
        if not validCoordinate(x) or not validCoordinate(y) then return nil, "invalid_coordinate" end
        if payload == nil then payload = {} end
        if type(payload) ~= "table" then return nil, "invalid_payload" end

        local queue, err = loadQueue(kind)
        if not queue then return nil, err end

        local key = coordinateKey(x, y)
        local existing = queue.entries[key]
        if existing then
            if deepEqual(existing.payload or {}, payload) then
                return deepCopy(existing), nil, false
            end

            queue = deepCopy(queue)
            existing = queue.entries[key]
            existing.state = "repair_required"
            existing.revision = (existing.revision or 0) + 1
            existing.repairRequired = "payload_conflict"
            existing.lastError = "A different payload was queued for the same kind and coordinate."
            existing.updatedAt = now()
            local saved, saveErr = saveQueue(kind, queue)
            if not saved then return nil, saveErr end
            return nil, "payload_conflict", false
        end

        local createdAt = now()
        local record = {
            schemaVersion = 1,
            revision = 0,
            id = kind .. ":" .. key,
            kind = kind,
            x = x,
            y = y,
            payload = deepCopy(payload),
            state = "pending",
            attempts = 0,
            claimOwner = nil,
            claimUntil = nil,
            nextAttemptAt = createdAt,
            createdAt = createdAt,
            updatedAt = createdAt,
            completedAt = nil,
            result = nil,
            lastError = nil,
            repairRequired = nil
        }

        queue = deepCopy(queue)
        queue.entries[key] = record
        local saved, saveErr = saveQueue(kind, queue)
        if not saved then return nil, saveErr end
        return deepCopy(record), nil, true
    end

    function CosmicVaultTerritory.ClaimMaterialization(kind, x, y, claimant, leaseSeconds)
        if claimant == nil or tostring(claimant) == "" then return nil, "invalid_claimant" end
        leaseSeconds = tonumber(leaseSeconds) or 60
        if leaseSeconds <= 0 then return nil, "invalid_lease" end

        local record, err, queue = getEntry(kind, x, y)
        if err then return nil, err end
        if not record then return nil, "missing" end

        local currentTime = now()
        local reclaimable = record.state == "materializing"
            and type(record.claimUntil) == "number"
            and record.claimUntil <= currentTime
        local due = type(record.nextAttemptAt) ~= "number" or record.nextAttemptAt <= currentTime

        if record.state == "materializing" and not reclaimable then return nil, "already_claimed" end
        if record.state == "retryable" and not due then return nil, "not_due" end
        if record.state ~= "pending" and record.state ~= "retryable" and not reclaimable then
            return nil, record.state
        end

        queue = deepCopy(queue)
        record = queue.entries[coordinateKey(x, y)]
        record.state = "materializing"
        record.revision = (record.revision or 0) + 1
        record.attempts = (record.attempts or 0) + 1
        record.claimOwner = tostring(claimant)
        record.claimUntil = currentTime + leaseSeconds
        record.updatedAt = currentTime
        record.lastError = nil

        local saved, saveErr = saveQueue(kind, queue)
        if not saved then return nil, saveErr end
        return deepCopy(record), nil
    end

    function CosmicVaultTerritory.CompleteMaterialization(kind, x, y, claimant, result)
        if type(result) ~= "table" then return nil, "invalid_result" end

        local record, err, queue = getEntry(kind, x, y)
        if err then return nil, err end
        if not record then return nil, "missing" end
        if record.state == "succeeded" then
            publishCompletedMaterialization(record)
            return deepCopy(record), nil
        end
        if record.state ~= "materializing" then return nil, "invalid_state" end
        if record.claimOwner ~= tostring(claimant) then return nil, "claimant_mismatch" end

        queue = deepCopy(queue)
        record = queue.entries[coordinateKey(x, y)]
        local completedAt = now()
        record.state = "succeeded"
        record.revision = (record.revision or 0) + 1
        record.result = deepCopy(result)
        record.completedAt = completedAt
        record.updatedAt = completedAt
        record.claimOwner = nil
        record.claimUntil = nil
        record.nextAttemptAt = nil
        record.lastError = nil

        local saved, saveErr = saveQueue(kind, queue)
        if not saved then return nil, saveErr end
        publishCompletedMaterialization(record)
        return deepCopy(record), nil
    end

    function CosmicVaultTerritory.RetryMaterialization(kind, x, y, claimant, errorText, delaySeconds)
        local record, err, queue = getEntry(kind, x, y)
        if err then return nil, err end
        if not record then return nil, "missing" end
        if record.state ~= "materializing" then return nil, "invalid_state" end
        if record.claimOwner ~= tostring(claimant) then return nil, "claimant_mismatch" end

        queue = deepCopy(queue)
        record = queue.entries[coordinateKey(x, y)]
        local currentTime = now()
        record.lastError = tostring(errorText or "materialization_failed")
        record.revision = (record.revision or 0) + 1
        record.updatedAt = currentTime
        record.claimOwner = nil
        record.claimUntil = nil

        if (record.attempts or 0) >= MAX_ATTEMPTS then
            record.state = "failed_permanent"
            record.nextAttemptAt = nil
            record.repairRequired = "automatic_attempts_exhausted"
        else
            record.state = "retryable"
            record.nextAttemptAt = currentTime + math.max(0, tonumber(delaySeconds) or 60)
        end

        local saved, saveErr = saveQueue(kind, queue)
        if not saved then return nil, saveErr end
        return deepCopy(record), nil
    end

    function CosmicVaultTerritory.RequireMaterializationRepair(kind, x, y, claimant, errorText)
        local record, err, queue = getEntry(kind, x, y)
        if err then return nil, err end
        if not record then return nil, "missing" end
        if record.state ~= "materializing" then return nil, "invalid_state" end
        if record.claimOwner ~= tostring(claimant) then return nil, "claimant_mismatch" end

        queue = deepCopy(queue)
        record = queue.entries[coordinateKey(x, y)]
        record.state = "repair_required"
        record.revision = (record.revision or 0) + 1
        record.updatedAt = now()
        record.claimOwner = nil
        record.claimUntil = nil
        record.nextAttemptAt = nil
        record.lastError = tostring(errorText or "materialization_ambiguous")
        record.repairRequired = record.lastError
        local saved, saveErr = saveQueue(kind, queue)
        if not saved then return nil, saveErr end
        return deepCopy(record), nil
    end

    function CosmicVaultTerritory.GetMaterialization(kind, x, y)
        local record, err = getEntry(kind, x, y)
        if err then return nil, err end
        if not record then return nil, "missing" end
        return deepCopy(record), nil
    end

    function CosmicVaultTerritory.ResolveMaterializationRepair(kind, x, y, action, result)
        local record, err, queue = getEntry(kind, x, y)
        if err then return nil, err end
        if not record then return nil, "missing" end
        if record.state ~= "repair_required" and record.state ~= "failed_permanent" then
            return nil, "invalid_state"
        end
        if action ~= "retry" and action ~= "mark-complete" and action ~= "abandon" then
            return nil, "invalid_action"
        end
        if action == "mark-complete" and type(result) ~= "table" then
            return nil, "invalid_result"
        end

        if kind == "flip" then
            local bridgeLoaded, warBridge = pcall(include, "cosmicwarbridge")
            if bridgeLoaded and warBridge and warBridge.resolveMaterializedTerritoryRepair then
                local resolved, resolveError = warBridge.resolveMaterializedTerritoryRepair(
                    operationId(record), action)
                if not resolved then return nil, "war_bridge_" .. tostring(resolveError) end
            end
        end

        queue = deepCopy(queue)
        record = queue.entries[coordinateKey(x, y)]
        record.updatedAt = now()
        record.revision = (record.revision or 0) + 1
        record.claimOwner = nil
        record.claimUntil = nil
        record.lastError = nil
        record.repairRequired = nil

        if action == "retry" then
            record.state = "retryable"
            record.attempts = 0
            record.nextAttemptAt = now()
        elseif action == "mark-complete" then
            record.state = "succeeded"
            record.result = deepCopy(result)
            record.completedAt = now()
            record.nextAttemptAt = nil
        else
            record.state = "abandoned"
            record.nextAttemptAt = nil
        end

        local saved, saveErr = saveQueue(kind, queue)
        if not saved then return nil, saveErr end
        return deepCopy(record), nil
    end

    function CosmicVaultTerritory.ListMaterializations(kind, states)
        if states ~= nil and type(states) ~= "table" then return nil, "invalid_states" end
        local queue, err = loadQueue(kind)
        if not queue then return nil, err end

        local records = {}
        for _, record in pairs(queue.entries) do
            if states == nil or states[record.state] == true then
                table.insert(records, deepCopy(record))
            end
        end
        table.sort(records, function(a, b) return a.id < b.id end)
        return records, nil
    end

    function CosmicVaultTerritory.PruneMaterializations(kind, limit)
        local queue, err = loadQueue(kind)
        if not queue then return nil, err end

        local currentTime = now()
        local removed = 0
        limit = math.max(1, math.min(25, tonumber(limit) or 25))
        local workingQueue = deepCopy(queue)
        for key, record in pairs(workingQueue.entries) do
            if removed >= limit then break end
            if record.state == "succeeded" and type(record.completedAt) == "number"
                    and currentTime - record.completedAt >= TOMBSTONE_LIFETIME then
                workingQueue.entries[key] = nil
                removed = removed + 1
            end
        end

        if removed > 0 then
            local saved, saveErr = saveQueue(kind, workingQueue)
            if not saved then return nil, saveErr end
        end
        return removed, nil
    end

    function CosmicVaultTerritory.ImportLegacyMaterializations()
        local server = Server()
        if server:getValue("cv_materialization_v1_legacy_imported") then return true, nil end

        local errors = {}
        local flips = server:getValue("CosmicVault_PendingFlips")
        if type(flips) == "string" then
            for token in string.gmatch(flips, "([^,]+)") do
                local x, y, factionIndex = string.match(token, "^(-?%d+)__(-?%d+)__(-?%d+)$")
                if x and y and factionIndex then
                    local _, err = CosmicVaultTerritory.QueueMaterialization(
                        "flip", tonumber(x), tonumber(y), {factionIndex = tonumber(factionIndex)})
                    if err and err ~= "payload_conflict" then table.insert(errors, err) end
                end
            end
        end

        local expansions = server:getValue("CosmicVault_PendingExpansions")
        if type(expansions) == "string" then
            for token in string.gmatch(expansions, "([^,]+)") do
                local x, y, factionText, pirateText = string.match(
                    token, "^(-?%d+)__(-?%d+)__([%-%w]+)__([%a]+)$")
                if x and y and factionText and (pirateText == "true" or pirateText == "false") then
                    local factionIndex = factionText == "nil" and nil or tonumber(factionText)
                    local _, err = CosmicVaultTerritory.QueueMaterialization("expansion", tonumber(x), tonumber(y), {
                        factionIndex = factionIndex,
                        isPirate = pirateText == "true"
                    })
                    if err and err ~= "payload_conflict" then table.insert(errors, err) end
                end
            end
        end

        if #errors > 0 then return nil, table.concat(errors, ",") end
        server:setValue("cv_materialization_v1_legacy_imported", true)
        return true, nil
    end

    local function serializeZones(zones)
        local parts = {}
        for key, zone in pairs(zones) do
            table.insert(parts, key .. "=" .. zone.x .. "," .. zone.y .. "," .. tostring(zone.invader) .. "," .. tostring(zone.defender) .. "," .. tostring(zone.endTime) .. "," .. tostring(zone.startTime))
        end
        return table.concat(parts, ";")
    end

    local function deserializeZones(str)
        local zones = {}
        if type(str) ~= "string" or str == "" then return zones end
        local fragments = str:split(";")
        for _, part in ipairs(fragments) do
            local kv = part:split("=")
            if #kv == 2 then
                local key = kv[1]
                local vals = kv[2]:split(",")
                if #vals >= 5 then
                    zones[key] = {
                        x = tonumber(vals[1]),
                        y = tonumber(vals[2]),
                        invader = tonumber(vals[3]) or vals[3],
                        defender = tonumber(vals[4]) or vals[4],
                        endTime = tonumber(vals[5]),
                        startTime = tonumber(vals[6]) or (tonumber(vals[5]) - 3600)
                    }
                end
            end
        end
        return zones
    end

--- Gets all active contested zones
-- @return (table) Contested zones list
    function CosmicVaultTerritory.getContestedZones()
        local server = Server()
        local zonesStr = server:getValue("CosmicVault_ContestedZones")
        local zones = deserializeZones(zonesStr)
        return zones
    end

--- Sets the contested state of a zone
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param state (boolean) Contested state
-- @param attackers (table) Attacking faction info
    function CosmicVaultTerritory.setContestedZone(x, y, invadingFactionIndex, defendingFactionIndex, durationMinutes)
    if not x or not y then return end
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y
        zones[key] = {
            x = x,
            y = y,
            invader = invadingFactionIndex,
            defender = defendingFactionIndex,
            endTime = Server().unpausedRuntime + (durationMinutes * 60),
            startTime = Server().unpausedRuntime
        }

        Server():setValue("CosmicVault_ContestedZones", serializeZones(zones))
        include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Sector " .. x .. ":" .. y .. " is now Contested!")
    end

--- Removes a contested zone from the tracking table without resolving a victor
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
    function CosmicVaultTerritory.removeContestedZone(x, y)
        if not x or not y then return end
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y

        if zones[key] then
            zones[key] = nil
            Server():setValue("CosmicVault_ContestedZones", serializeZones(zones))
        end
    end

--- Resolves a siege outcome mathematically, deferring station flipping until player visit
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param newFactionIndex (number) The winning faction index
    function CosmicVaultTerritory.resolveSiege(x, y, newFactionIndex)
    if not x or not y or not newFactionIndex then return end
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y
        local previousFactionIndex = zones[key] and tonumber(zones[key].defender) or nil

        local _, queueError = CosmicVaultTerritory.QueueMaterialization(
            "flip", x, y, {
                factionIndex = newFactionIndex,
                previousFactionIndex = previousFactionIndex
            })
        if queueError then return nil, queueError end

        if zones[key] then
            zones[key] = nil
            Server():setValue("CosmicVault_ContestedZones", serializeZones(zones))
        end

        include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Sector " .. x .. ":" .. y .. " mathematically conquered by faction " .. tostring(newFactionIndex))
        return true
    end

--- Server update loop for territory control
-- @param timeStep (number) The time step
    function CosmicVaultTerritory.updateServer(timeStep)
        CosmicVaultTerritory.ImportLegacyMaterializations()
        local kindRegistry = loadKindRegistry()
        local kinds = deepCopy(knownKinds)
        for kind in pairs(kindRegistry and kindRegistry.kinds or {}) do kinds[kind] = true end
        for kind in pairs(kinds) do
            CosmicVaultTerritory.PruneMaterializations(kind, 25)
        end

        local zones = CosmicVaultTerritory.getContestedZones()
        local currentTime = Server().unpausedRuntime

        for key, zone in pairs(zones) do
            if currentTime >= zone.endTime then
                -- The background siege timer completed! The AI won mathematically.
                CosmicVaultTerritory.resolveSiege(zone.x, zone.y, zone.invader)
            end
        end
    end

--- Expands a faction's territory mathematically, deferring station generation until player visit
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param factionIndex (number) The faction index expanding (or nil if pirate generation)
-- @param isPirate (boolean) If true, generates a pirate outpost instead
    function CosmicVaultTerritory.expandToSector(x, y, factionIndex, isPirate)
        if not x or not y then return end

        local _, queueError, created = CosmicVaultTerritory.QueueMaterialization("expansion", x, y, {
            factionIndex = factionIndex,
            isPirate = isPirate == true
        })
        if queueError then return nil, queueError end

        if created then
            if not isPirate and factionIndex then
                local faction = Faction(factionIndex)
                if faction then
                    include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Faction " .. faction.name .. " scheduled expansion to " .. x .. ":" .. y)
                end
            else
                include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Pirates scheduled expansion to " .. x .. ":" .. y)
            end
        end
        return true
    end

--- Finds the sectors where two named factions' territories actually meet -- any sector
-- controlled by one of the two whose immediate neighbor is controlled by the other. Scans a
-- bounded square centered on the midpoint of the two factions' home sectors, out to `radius`
-- sectors in each direction; getControllingFaction() is a faction-map lookup, not a sector
-- load, so this stays cheap even at the default radius, but the scan is still bounded rather
-- than sweeping the whole galaxy.
-- @param factionAIndex (number) First faction's index
-- @param factionBIndex (number) Second faction's index
-- @param radius (number) How far from the midpoint to scan, in sectors (default 15)
-- @return (table) A list of {x, y} sectors bordering the other faction's territory
    function CosmicVaultTerritory.getBorderSectors(factionAIndex, factionBIndex, radius)
        if not factionAIndex or not factionBIndex or factionAIndex == factionBIndex then return {} end
        radius = radius or 15

        local factionA = Faction(factionAIndex)
        local factionB = Faction(factionBIndex)
        if not factionA or not factionB then return {} end

        local hxA, hyA = factionA:getHomeSectorCoordinates()
        local hxB, hyB = factionB:getHomeSectorCoordinates()
        if not hxA or not hyA or not hxB or not hyB then return {} end

        local cx = math.floor((hxA + hxB) / 2 + 0.5)
        local cy = math.floor((hyA + hyB) / 2 + 0.5)

        local galaxy = Galaxy()
        local owners = {}
        local function ownerAt(x, y)
            local key = x .. ":" .. y
            local cached = owners[key]
            if cached == nil then
                local f = galaxy:getControllingFaction(x, y)
                cached = f and f.index or false
                owners[key] = cached
            end
            if cached == false then return nil end
            return cached
        end

        local borders = {}
        for x = cx - radius, cx + radius do
            for y = cy - radius, cy + radius do
                local owner = ownerAt(x, y)
                if owner == factionAIndex or owner == factionBIndex then
                    local other = (owner == factionAIndex) and factionBIndex or factionAIndex
                    local neighbors = { {x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1} }
                    for _, n in pairs(neighbors) do
                        if ownerAt(n[1], n[2]) == other then
                            table.insert(borders, {x = x, y = y})
                            break
                        end
                    end
                end
            end
        end

        return borders
    end

end

return CosmicVaultTerritory
