package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicVaultTerritory = include("cosmicvaultterritory")

local function operationId(record)
    return record.id .. ":" .. tostring(record.createdAt or 0)
end

local function controllingFactionIndex(x, y)
    local controller = Galaxy():getControllingFaction(x, y)
    if type(controller) == "number" then return controller end
    return controller and controller.index or nil
end

local function findMaterializedStation(recordId)
    for _, station in pairs({Sector():getEntitiesByType(EntityType.Station)}) do
        if station:getValue("cv_materialization_id") == recordId then
            return station
        end
    end
end

local function processFlip(x, y, claimant)
    local record, claimError = CosmicVaultTerritory.ClaimMaterialization("flip", x, y, claimant, 60)
    if not record then return claimError end

    local factionIndex = tonumber(record.payload and record.payload.factionIndex)
    if not factionIndex or not Faction(factionIndex) then
        CosmicVaultTerritory.RetryMaterialization("flip", x, y, claimant, "invalid_target_faction", 300)
        return "invalid_target_faction"
    end

    local previousFactionIndex = tonumber(record.payload and record.payload.previousFactionIndex)
        or controllingFactionIndex(x, y)
    local changed = 0
    local targetOwned = 0
    for _, station in pairs({Sector():getEntitiesByType(EntityType.Station)}) do
        if station.factionIndex == factionIndex then
            targetOwned = targetOwned + 1
        else
            local currentFaction = Faction(station.factionIndex)
            if currentFaction and currentFaction.isAIFaction then
                station.factionIndex = factionIndex
                changed = changed + 1
                targetOwned = targetOwned + 1
            end
        end
    end

    local controllerIndex = controllingFactionIndex(x, y)
    if changed > 0 or targetOwned > 0 or controllerIndex == factionIndex then
        local bridgeLoaded, warBridge = pcall(include, "cosmicwarbridge")
        if bridgeLoaded and warBridge and warBridge.recordMaterializedTerritory then
            local recorded, bridgeError = warBridge.recordMaterializedTerritory(
                operationId(record), previousFactionIndex, factionIndex)
            if not recorded then
                if bridgeError == "repair_required" then
                    CosmicVaultTerritory.RequireMaterializationRepair(
                        "flip", x, y, claimant, "war_bridge_repair_required")
                else
                    CosmicVaultTerritory.RetryMaterialization(
                        "flip", x, y, claimant, "war_bridge_" .. tostring(bridgeError), 300)
                end
                return bridgeError
            end
        end

        CosmicVaultTerritory.CompleteMaterialization("flip", x, y, claimant, {
            factionIndex = factionIndex,
            stationsChanged = changed,
            controllingFactionIndex = controllerIndex
        })
        include("cosmicvaultdebug").info("Cosmic Vault",
            "[Cosmic Vault] Materialized territory flip in " .. x .. ":" .. y
                .. " to faction " .. tostring(factionIndex))
        return nil
    end

    CosmicVaultTerritory.RetryMaterialization("flip", x, y, claimant, "flip_not_observable", 300)
    return "flip_not_observable"
end

local function createExpansionStation(record, x, y)
    local payload = record.payload or {}
    local SectorGenerator = include("SectorGenerator")
    local generator = SectorGenerator(x, y)

    if payload.isPirate == true then
        local level = Balancing_GetPirateLevel(x, y)
        local faction = Galaxy():getPirateFaction(level)
        if not faction then return nil, "pirate_faction_missing" end

        if random():getFloat() < 0.5 then
            local station = generator:createStation(faction, "data/scripts/entity/merchants/smugglersmarket.lua")
            if station then station.title = "Smuggler's Hideout" end
            return station, station and nil or "station_creation_failed"
        end

        local station = generator:createStation(faction, "data/scripts/entity/merchants/shipyard.lua")
        if station then station.title = "Pirate Shipyard" end
        return station, station and nil or "station_creation_failed"
    end

    local factionIndex = tonumber(payload.factionIndex)
    local faction = factionIndex and Faction(factionIndex)
    if not faction then return nil, "expansion_faction_missing" end

    local stationScripts = {
        "data/scripts/entity/merchants/militaryoutpost.lua",
        "data/scripts/entity/merchants/resourcetrader.lua",
        "data/scripts/entity/merchants/tradingpost.lua",
        "data/scripts/entity/merchants/researchstation.lua"
    }
    local script = stationScripts[random():getInt(1, #stationScripts)]
    local station = generator:createStation(faction, script)
    return station, station and nil or "station_creation_failed"
end

local function processExpansion(x, y, claimant)
    local beforeClaim = CosmicVaultTerritory.GetMaterialization("expansion", x, y)
    local recoveringAmbiguousLease = beforeClaim
        and beforeClaim.state == "materializing"
        and type(beforeClaim.claimUntil) == "number"
        and beforeClaim.claimUntil <= Server().unpausedRuntime
    local record, claimError = CosmicVaultTerritory.ClaimMaterialization("expansion", x, y, claimant, 60)
    if not record then return claimError end

    local materializationId = operationId(record)
    local existing = findMaterializedStation(materializationId)
    if existing then
        CosmicVaultTerritory.CompleteMaterialization("expansion", x, y, claimant, {
            materializationId = materializationId,
            recovered = true
        })
        return nil
    end
    if recoveringAmbiguousLease then
        CosmicVaultTerritory.RequireMaterializationRepair("expansion", x, y, claimant,
            "station_creation_ambiguous_after_lease_expiry")
        return "repair_required"
    end

    local station, creationError = createExpansionStation(record, x, y)
    if not station then
        CosmicVaultTerritory.RetryMaterialization(
            "expansion", x, y, claimant, creationError or "station_creation_failed", 300)
        return creationError
    end

    station:setValue("cv_materialization_id", materializationId)
    CosmicVaultTerritory.CompleteMaterialization("expansion", x, y, claimant, {
        materializationId = materializationId,
        stationTitle = station.title or ""
    })
    include("cosmicvaultdebug").info("Cosmic Vault",
        "[Cosmic Vault] Materialized expansion in " .. x .. ":" .. y)
    return nil
end

function initialize()
    if onServer() then
        CosmicVaultTerritory.ImportLegacyMaterializations()
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    if not onServer() then return end

    CosmicVaultTerritory.ImportLegacyMaterializations()
    local claimant = "vault-player:" .. tostring(playerIndex)
    processFlip(x, y, claimant)
    processExpansion(x, y, claimant)
end
