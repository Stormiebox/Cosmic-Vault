
-- Cosmic War is an optional sister mod from Vault's perspective (Vault is the
-- foundational dependency; nothing here requires War to be installed), so this
-- must be a soft include - a bare include("cosmicwarbridge") would throw
-- "module not found" and break this entire library on any install that has
-- Vault without War (e.g. Vault + Overhaul only).
local cw_ok, cw_bridge = pcall(include, "cosmicwarbridge")
if not cw_ok then cw_bridge = nil end
local FactionEradicationUtility = include("factioneradicationutility")
local CosmicVaultData = include("cosmicvaultdata")
local CosmicVaultEconomy = {}

local MARKET_KEY = "cv_market_events_v1"
local MARKET_VERSION = 1
local DEFAULT_DURATION = 1800
local TERMINAL_RETENTION = 7 * 24 * 60 * 60

local function marketNow()
    local server = Server()
    return server and server.unpausedRuntime or 0
end

local function marketCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[marketCopy(key, seen)] = marketCopy(item, seen)
    end
    return copy
end

local function loadMarketEvents()
    local record, err = CosmicVaultData.GetRecord(Server(), MARKET_KEY, MARKET_VERSION)
    if not record and err == "missing" then
        record = {schemaVersion = MARKET_VERSION, revision = 0, events = {}}
    elseif not record then
        return nil, err
    end

    if type(record.revision) ~= "number" or type(record.events) ~= "table" then
        return nil, "corrupt"
    end
    for eventId, event in pairs(record.events) do
        if type(eventId) ~= "string" or type(event) ~= "table"
                or event.eventId ~= eventId or type(event.revision) ~= "number"
                or type(event.state) ~= "string" then
            return nil, "corrupt"
        end
    end
    return record, nil
end

local function saveMarketEvents(record)
    record.revision = (record.revision or 0) + 1
    local saved, err = CosmicVaultData.SetRecord(Server(), MARKET_KEY, record)
    if not saved then
        record.revision = math.max(0, record.revision - 1)
        return nil, err
    end
    return true, nil
end

local function eventScopeMatches(event, sourceId, goodName, x, y, radius)
    return event.sourceId == sourceId
        and event.goodName == goodName
        and event.x == x
        and event.y == y
        and event.radius == radius
end

local function maintainMarketEvents(record, currentTime)
    local changed = false
    local removed = 0
    for eventId, event in pairs(record.events) do
        if event.state == "active" and type(event.expiresAt) == "number" and event.expiresAt <= currentTime then
            event.state = "expired"
            event.endedAt = event.expiresAt
            event.endReason = "expired"
            event.revision = (event.revision or 0) + 1
            changed = true
        elseif removed < 25 and (event.state == "expired" or event.state == "ended") then
            local terminalAt = event.endedAt or event.expiresAt
            if type(terminalAt) == "number" and currentTime - terminalAt >= TERMINAL_RETENTION then
                record.events[eventId] = nil
                removed = removed + 1
                changed = true
            end
        end
    end
    return changed
end

-- Famine Score logic:
-- 0 = Normal, 1-100 = Struggling, >100 = Famine

function CosmicVaultEconomy.addFamineScore(factionIndex, amount)
    if not onServer() then return end
    local server = Server()
    if not server then return end

    local key = "cv_famine_" .. tostring(factionIndex)
    local currentScore = server:getValue(key) or 0
    currentScore = math.max(0, currentScore + amount)

    server:setValue(key, currentScore)

    -- Synergy: Deep Economy Driving Warfare
    if currentScore >= 100 then
        local starvingFaction = Faction(factionIndex)
        if starvingFaction then
            -- Cap simultaneous Famine Wars to 1: Do not declare a new war if already fighting one
            if starvingFaction:getValue("enemy_faction") and starvingFaction:getValue("enemy_faction") > 0 then
                return currentScore
            end

            local factions = {}
            local factionStr = server:getValue("factions")
            if type(factionStr) == "string" and factionStr ~= "" then
                for id in string.gmatch(factionStr, "([^,]+)") do
                    local f = Faction(tonumber(id))
                    if f then table.insert(factions, f) end
                end
            end
            local bestTarget = nil
            local bestTargetWealth = -1

            for _, f in pairs(factions) do
                if f.index ~= factionIndex and not f.isPlayer and not f.isAlliance then
                    local isEradicated = false
                    if FactionEradicationUtility and FactionEradicationUtility.isFactionEradicated then
                        isEradicated = FactionEradicationUtility.isFactionEradicated(f.index)
                    end

                    if not isEradicated then
                        local wealth = f.money or 0
                        if wealth > bestTargetWealth then
                            bestTarget = f
                            bestTargetWealth = wealth
                        end
                    end
                end
            end

            if bestTarget and cw_bridge and cw_bridge.forceDeclareWar then
                cw_bridge.forceDeclareWar(starvingFaction, bestTarget)

                local CosmicVaultNews = include("cosmicvaultnews")
                if CosmicVaultNews and CosmicVaultNews.publishArticle then
                    CosmicVaultNews.publishArticle({
                        title = "Desperation War: " .. tostring(starvingFaction.name) .. " Attacks " .. tostring(bestTarget.name),
                        content = "Driven by critical resource shortages and a surging famine score, the " .. tostring(starvingFaction.name) .. " military has launched a desperate invasion into " .. tostring(bestTarget.name) .. " territory to seize their wealth and supplies.\n\nGalactic economists are calling this the direct result of a collapsed market.",
                        category = "Conflict"
                    })
                end

                -- Reset famine score slightly so they don't declare war again instantly
                server:setValue(key, 80)
            end
        end
    end

    return currentScore
end

function CosmicVaultEconomy.getFamineScore(factionIndex)
    if type(Server) == "function" then
        local server = Server()
        if server then
            return server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
        end
    end
    return 0
end

function CosmicVaultEconomy.setFamineScore(factionIndex, amount)
    if type(Server) == "function" then
        local server = Server()
        if server then
            local key = "cv_famine_" .. tostring(factionIndex)
            server:setValue(key, math.max(0, amount))
        end
    end
end

function CosmicVaultEconomy.getFamineLevel(factionIndex)
    local score = CosmicVaultEconomy.getFamineScore(factionIndex)
    if score >= 100 then
        return "Severe Famine"
    elseif score >= 50 then
        return "Resource Starved"
    elseif score > 0 then
        return "Struggling"
    else
        return "Stable"
    end
end

--- Starts or refreshes a persistent regional market event.
-- @param options (table) Event identity, scope, type, duration, delta, and notification preference
-- @return (table|nil, string|nil) The stored event or an error code
function CosmicVaultEconomy.StartMarketEvent(options)
    if not onServer() then return nil, "server_only" end
    if type(options) ~= "table" then return nil, "invalid_options" end

    local eventId = options.eventId
    local sourceId = options.sourceId
    local goodName = options.goodName
    local eventType = type(options.eventType) == "string" and string.lower(options.eventType) or nil
    if type(eventId) ~= "string" or eventId == "" then return nil, "invalid_event_id" end
    if type(sourceId) ~= "string" or sourceId == "" then return nil, "invalid_source_id" end
    if type(goodName) ~= "string" or goodName == "" then return nil, "invalid_good_name" end
    if type(options.x) ~= "number" or type(options.y) ~= "number" then return nil, "invalid_coordinates" end
    if type(options.radius) ~= "number" or options.radius < 0 then return nil, "invalid_radius" end
    if eventType ~= "boom" and eventType ~= "crash" then return nil, "invalid_event_type" end

    local delta = options.delta
    if delta == nil then delta = eventType == "boom" and 0.10 or -0.10 end
    if type(delta) ~= "number" then return nil, "invalid_delta" end

    local duration = options.duration == nil and DEFAULT_DURATION or options.duration
    if type(duration) ~= "number" or duration <= 0 then return nil, "invalid_duration" end
    if options.notify ~= nil and type(options.notify) ~= "boolean" then return nil, "invalid_notify" end

    local record, loadError = loadMarketEvents()
    if not record then return nil, loadError end
    local currentTime = marketNow()
    local working = marketCopy(record)
    maintainMarketEvents(working, currentTime)

    local existing = working.events[eventId]
    if existing and not eventScopeMatches(
            existing, sourceId, goodName, options.x, options.y, options.radius) then
        return nil, "event_id_conflict"
    end

    if not existing then
        for _, candidate in pairs(working.events) do
            if eventScopeMatches(candidate, sourceId, goodName, options.x, options.y, options.radius) then
                existing = candidate
                break
            end
        end
    end

    local notify = options.notify ~= false
    local event
    if existing then
        event = existing
        event.eventType = eventType
        event.priceDelta = delta
        event.startedAt = currentTime
        event.expiresAt = currentTime + duration
        event.state = "active"
        event.notify = notify
        event.endedAt = nil
        event.endReason = nil
        event.lastError = nil
        event.repairRequired = nil
        event.revision = (event.revision or 0) + 1
    else
        event = {
            schemaVersion = MARKET_VERSION,
            revision = 1,
            eventId = eventId,
            sourceId = sourceId,
            goodName = goodName,
            x = options.x,
            y = options.y,
            radius = options.radius,
            eventType = eventType,
            priceDelta = delta,
            startedAt = currentTime,
            expiresAt = currentTime + duration,
            state = "active",
            notify = notify,
            endedAt = nil,
            endReason = nil,
            migrationProvenance = "native",
            lastError = nil,
            repairRequired = nil
        }
        working.events[eventId] = event
    end

    local saved, saveError = saveMarketEvents(working)
    if not saved then return nil, saveError end

    if notify then
        Server():broadcastChatMessage(
            "Server"%_T,
            ChatMessageType.Economy,
            "Market event %s for %s started near (%d, %d)."%_T,
            eventType,
            goodName,
            options.x,
            options.y)
    end
    return marketCopy(event), nil
end

--- Reads one market event and expires it when its deadline has passed.
function CosmicVaultEconomy.GetMarketEvent(eventId)
    if not onServer() then return nil, "server_only" end
    if type(eventId) ~= "string" or eventId == "" then return nil, "invalid_event_id" end

    local record, loadError = loadMarketEvents()
    if not record then return nil, loadError end
    local working = marketCopy(record)
    local changed = maintainMarketEvents(working, marketNow())
    if changed then
        local saved, saveError = saveMarketEvents(working)
        if not saved then return nil, saveError end
    end

    local event = working.events[eventId]
    if not event then return nil, "missing" end
    return marketCopy(event), nil
end

--- Ends an active market event without deleting its audit record.
function CosmicVaultEconomy.EndMarketEvent(eventId, reason)
    if not onServer() then return nil, "server_only" end
    if type(eventId) ~= "string" or eventId == "" then return nil, "invalid_event_id" end

    local record, loadError = loadMarketEvents()
    if not record then return nil, loadError end
    local event = record.events[eventId]
    if not event then return nil, "missing" end
    if event.state == "ended" or event.state == "expired" then return marketCopy(event), nil end
    if event.state ~= "active" then return nil, "invalid_state" end

    local working = marketCopy(record)
    event = working.events[eventId]
    event.state = "ended"
    event.endedAt = marketNow()
    event.endReason = tostring(reason or "ended")
    event.revision = (event.revision or 0) + 1
    local saved, saveError = saveMarketEvents(working)
    if not saved then return nil, saveError end
    return marketCopy(event), nil
end

--- Returns the additive price delta from active events covering a good and sector.
function CosmicVaultEconomy.GetMarketPriceDelta(goodName, x, y, currentTime)
    if not onServer() then return 0, "server_only" end
    if type(goodName) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then
        return 0, "invalid_scope"
    end
    currentTime = type(currentTime) == "number" and currentTime or marketNow()

    local record, loadError = loadMarketEvents()
    if not record then return 0, loadError end
    local working = marketCopy(record)
    local changed = maintainMarketEvents(working, currentTime)

    local delta = 0
    for _, event in pairs(working.events) do
        if event.state == "active" and type(event.x) == "number"
                and type(event.y) == "number" and type(event.radius) == "number"
                and type(event.priceDelta) == "number"
                and (event.goodName == "All" or event.goodName == goodName) then
            local dx = x - event.x
            local dy = y - event.y
            if dx * dx + dy * dy <= event.radius * event.radius then
                delta = delta + event.priceDelta
            end
        end
    end

    if changed then
        local saved, saveError = saveMarketEvents(working)
        if not saved then return delta, saveError end
    end
    return delta, nil
end

function CosmicVaultEconomy.TriggerMarketEvent(goodName, x, y, radius, eventType)
    local sourceId = table.concat({"legacy", tostring(eventType), tostring(goodName), tostring(x), tostring(y), tostring(radius)}, ":")
    return CosmicVaultEconomy.StartMarketEvent({
        eventId = sourceId,
        sourceId = sourceId,
        goodName = goodName,
        x = x,
        y = y,
        radius = radius,
        eventType = eventType,
        notify = true
    })
end

-- Registers a dynamic price hook for a good. economyupdater.lua's
-- getSupplyDemandPriceChange() reads this same "CVE_PriceHook_<good>" key
-- (pipe-separated "scriptName::functionName" entries) every time it computes
-- that good's price, and invokes each registered hook with (good, factor),
-- multiplying the result into the final price change factor.
function CosmicVaultEconomy.registerPriceHook(goodName, scriptName, functionName)
    if not onServer() then return end
    if type(goodName) ~= "string" or type(scriptName) ~= "string" or type(functionName) ~= "string" then return end
    local server = Server()
    if not server then return end

    local key = "CVE_PriceHook_" .. string.gsub(goodName, "%s+", "_")
    local entry = scriptName .. "::" .. functionName
    local hooksStr = server:getValue(key) or ""

    for hook in string.gmatch(hooksStr, "([^|]+)") do
        if hook == entry then return end
    end

    server:setValue(key, hooksStr == "" and entry or (hooksStr .. "|" .. entry))
end

-- v4.0.0: generalizes a pattern Cosmic War built for its own Warbonds system
-- (a payout that scales off how a tracked score changed during a holding period, which a
-- player could otherwise game by personally applying the very relief action that would
-- guarantee a good outcome) into a reusable Vault primitive. Any mod with a similar
-- "snapshot a running total at the start of a hold, diff it at the end" need -- not just
-- Famine relief -- can share this instead of hand-rolling its own tracker per scoreKey.
function CosmicVaultEconomy.recordReliefApplied(scoreKey, factionIndex, amount)
    if not onServer() then return end
    if not scoreKey or not factionIndex or factionIndex <= 0 or not amount or amount <= 0 then return end
    local server = Server()
    if not server then return end
    local key = "cve_relief_" .. scoreKey .. "_" .. tostring(factionIndex)
    server:setValue(key, (server:getValue(key) or 0) + amount)
end

--- @return number the running total ever recorded for this scoreKey/faction (0 if none)
function CosmicVaultEconomy.getReliefApplied(scoreKey, factionIndex)
    if not scoreKey or not factionIndex or factionIndex <= 0 then return 0 end
    local server = Server()
    if not server then return 0 end
    return server:getValue("cve_relief_" .. scoreKey .. "_" .. tostring(factionIndex)) or 0
end

-- Registers a score family that should passively drift toward `floor` over time. Vault
-- doesn't run its own ticker for this (it has no Galaxy-attached background loop of its
-- own) -- a consuming mod's existing background script calls tickPassiveDecay() once per
-- faction per pass, so multiple mods/mechanics can share the registration and math instead
-- of each hand-building the same "drift a stored value back toward a baseline" logic.
local passiveDecayRegistry = {}

function CosmicVaultEconomy.registerPassiveDecay(scoreKeyPrefix, amountPerHour, floor)
    if type(scoreKeyPrefix) ~= "string" or type(amountPerHour) ~= "number" then return end
    passiveDecayRegistry[scoreKeyPrefix] = { amountPerHour = amountPerHour, floor = floor or 0 }
end

--- Applies one registered family's decay to one faction for this tick. `timeStep` is the
-- real elapsed seconds since the caller's last tick (its own getUpdateInterval()).
function CosmicVaultEconomy.tickPassiveDecay(scoreKeyPrefix, factionIndex, timeStep)
    if not onServer() then return end
    local cfg = passiveDecayRegistry[scoreKeyPrefix]
    if not cfg or not factionIndex or not timeStep then return end
    local server = Server()
    if not server then return end

    local key = scoreKeyPrefix .. tostring(factionIndex)
    local current = server:getValue(key) or 0
    if current <= cfg.floor then return end

    local decay = cfg.amountPerHour * (timeStep / 3600)
    server:setValue(key, math.max(cfg.floor, current - decay))
end

--- Reads Cosmic War's published galaxy-wide hostility index (the sum of every AI
-- faction's current War Heat) -- a soft-optional read (returns 0 if Cosmic War isn't
-- installed, or hasn't published one yet) any Cosmic mod can use to scale its own systems
-- off "how much overall warfare is happening right now" without a hard dependency on
-- Cosmic War, the same soft-include spirit as this file's own `cw_bridge` above.
function CosmicVaultEconomy.getGalacticHostilityIndex()
    local server = Server()
    if not server then return 0 end
    return server:getValue("cw_galactic_hostility_index") or 0
end

return CosmicVaultEconomy
