-- namespace CosmicVaultRiftObserver
CosmicVaultRiftObserver = {}

local GUARDIAN_SCRIPT = "internal/dlc/rift/entity/xsotanriftguardian.lua"
local TRACKER_SCRIPT = "data/scripts/entity/cv_rift_escalation_tracker.lua"
local scansRemaining = 0

function CosmicVaultRiftObserver.scan()
    local sector = Sector()
    if not sector then return false end
    local found = false
    local allTracked = true
    for _, entity in pairs({sector:getEntitiesByScript(GUARDIAN_SCRIPT)}) do
        if valid(entity) then
            found = true
            if not entity:hasScript(TRACKER_SCRIPT) then
                entity:addScriptOnce(TRACKER_SCRIPT)
                allTracked = false
            end
        end
    end
    if found and allTracked then scansRemaining = 0 end
    return found and allTracked
end

function CosmicVaultRiftObserver.initialize()
    if not onServer() or not isIntoTheRiftDLCInstalled() then
        terminate()
        return
    end
    local sector = Sector()
    if not sector then return end
    sector:registerCallback("onEntityCreated", "onEntityCreated")
    scansRemaining = 5
    CosmicVaultRiftObserver.scan()
end

function CosmicVaultRiftObserver.onEntityCreated()
    -- Guardian identity scripts can be attached after creation, so the regular
    -- scan is scheduled after the creation callback has fully settled.
    scansRemaining = 5
    deferredCallback(1, "scan")
end

function CosmicVaultRiftObserver.getUpdateInterval()
    return 5
end

function CosmicVaultRiftObserver.updateServer()
    if scansRemaining <= 0 then return end
    scansRemaining = scansRemaining - 1
    CosmicVaultRiftObserver.scan()
end
