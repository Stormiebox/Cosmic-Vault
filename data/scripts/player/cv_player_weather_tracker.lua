-- namespace CosmicVaultPlayerWeatherTracker
CosmicVaultPlayerWeatherTracker = {}

local MANAGER = "data/scripts/server/cosmicvaultweather_server.lua"
local CONTROLLER = "data/scripts/sector/cv_environment_controller.lua"
local RIFT_OBSERVER = "data/scripts/sector/cv_rift_observer.lua"
local pending

local function now()
    local server = Server()
    return server and server.unpausedRuntime or 0
end

local function currentCoordinates()
    local player = Player()
    if not player then return nil end
    return player:getSectorCoordinates()
end

local function conditionIds(snapshot)
    local ids = {}
    for _, condition in ipairs(snapshot.conditions or {}) do table.insert(ids, condition.conditionId) end
    return ids
end

local function attachRiftObserver(x, y)
    if not Galaxy():sectorInRift(x, y) then return end
    local sector = Sector()
    if sector then sector:addScriptOnce(RIFT_OBSERVER) end
end

function CosmicVaultPlayerWeatherTracker.initialize()
    if not onServer() then return end
    Player():registerCallback("onSectorEntered", "onSectorEntered")
    CosmicVaultPlayerWeatherTracker.forceSectorCheck("entered")
end

function CosmicVaultPlayerWeatherTracker.onSectorEntered(playerIndex, x, y, sectorChangeType)
    if not onServer() then return end
    pending = nil
    CosmicVaultPlayerWeatherTracker.forceSectorCheck("entered")
end

function CosmicVaultPlayerWeatherTracker.weatherChanged(x, y, revision, reason)
    if not onServer() then return end
    local px, py = currentCoordinates()
    if px ~= x or py ~= y then return end
    CosmicVaultPlayerWeatherTracker.forceSectorCheck(reason or "changed")
end

function CosmicVaultPlayerWeatherTracker.forceSectorCheck(reason)
    if not onServer() then return end
    local x, y = currentCoordinates()
    if x == nil or y == nil then return end
    local sector = Sector()
    if not sector then return end

    attachRiftObserver(x, y)
    local status, snapshot, err = Galaxy():invokeFunction(MANAGER, "getCoordinateSnapshot", x, y)
    if status ~= 0 or type(snapshot) ~= "table" then return end

    if #snapshot.conditions == 0 and not sector:hasScript(CONTROLLER) then
        pending = nil
        return
    end

    if not sector:hasScript(CONTROLLER) then sector:addScriptOnce(CONTROLLER) end
    pending = {
        snapshot = snapshot,
        reason = reason or "reconciled",
        attempts = 0,
        nextAttemptAt = now() + 1
    }
end

function CosmicVaultPlayerWeatherTracker.getUpdateInterval()
    return 1
end

function CosmicVaultPlayerWeatherTracker.updateServer(timeStep)
    if not pending or now() < pending.nextAttemptAt then return end
    local sector = Sector()
    if not sector then
        pending = nil
        return
    end

    local x, y = currentCoordinates()
    if x ~= pending.snapshot.x or y ~= pending.snapshot.y then
        pending = nil
        return
    end

    pending.attempts = pending.attempts + 1
    if not sector:hasScript(CONTROLLER) then
        sector:addScriptOnce(CONTROLLER)
        pending.nextAttemptAt = now() + math.min(5, pending.attempts)
        local ids = conditionIds(pending.snapshot)
        if #ids > 0 then
            Galaxy():invokeFunction(MANAGER, "reportMaterialized", x, y,
                pending.snapshot.rootRevision, ids, false, "controller_attachment_failed")
        end
        if pending.attempts >= 5 then
            pending = nil
        end
        return
    end

    local status, rootRevision, ids = sector:invokeFunction(
        CONTROLLER, "reconcile", pending.snapshot, pending.reason)
    if status == 0 and rootRevision == pending.snapshot.rootRevision and type(ids) == "table" then
        if #ids > 0 then
            Galaxy():invokeFunction(MANAGER, "reportMaterialized", x, y,
                rootRevision, ids, true)
        end
        pending = nil
        return
    end

    pending.nextAttemptAt = now() + math.min(5, pending.attempts)
    local expectedIds = conditionIds(pending.snapshot)
    if #expectedIds > 0 then
        Galaxy():invokeFunction(MANAGER, "reportMaterialized", x, y,
            pending.snapshot.rootRevision, expectedIds, false, "controller_reconcile_failed")
    end
    if pending.attempts >= 5 then
        pending = nil
    end
end

-- Older managers called these functions with a full map. The canonical manager
-- now ignores that untrusted copy and requests only the player's coordinate.
function CosmicVaultPlayerWeatherTracker.syncWeatherMap(weatherMap)
    CosmicVaultPlayerWeatherTracker.forceSectorCheck("legacy_sync")
end

function CosmicVaultPlayerWeatherTracker.forceSectorCleanup()
    CosmicVaultPlayerWeatherTracker.forceSectorCheck("ended")
end
