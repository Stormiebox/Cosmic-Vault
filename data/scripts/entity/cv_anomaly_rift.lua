include("randomext")
include("galaxy")
include("faction")
include("data/scripts/lib/callable")

-- namespace CvAnomalyRift
CvAnomalyRift = {}
CvAnomalyRift.interactionDistance = 20

local CosmicVaultData = include("cosmicvaultdata")
local UpgradeGenerator = include("upgradegenerator")
local SectorTurretGenerator = include("sectorturretgenerator")

local RECORD_KEY = "cv_anomaly_rift_claim_v1"
local SCHEMA_VERSION = 1
local claimRecord

local function now()
    local server = Server()
    return server and server.unpausedRuntime or 0
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[copy(key)] = copy(item) end
    return result
end

local function defaultRecord()
    local timestamp = now()
    return {
        schemaVersion = SCHEMA_VERSION,
        revision = 1,
        state = "available",
        createdAt = timestamp,
        updatedAt = timestamp
    }
end

local function validRecord(record)
    if type(record) ~= "table" or record.schemaVersion ~= SCHEMA_VERSION
            or type(record.revision) ~= "number" or type(record.state) ~= "string"
            or type(record.createdAt) ~= "number" or type(record.updatedAt) ~= "number" then
        return false
    end
    return record.state == "available" or record.state == "claim_prepared"
        or record.state == "claimed" or record.state == "repair_required"
end

local function applyPresentation()
    if not onServer() then return end
    local entity = Entity()
    if claimRecord and claimRecord.state == "repair_required" then
        entity.title = "Unstable Spatial Rift [Repair Required]"
        entity:setValue("valuable_object", nil)
    elseif claimRecord and claimRecord.state == "claimed" then
        entity:setValue("valuable_object", nil)
    else
        entity:setValue("valuable_object", RarityType.Exceptional)
    end
end

local function persist(record)
    record.updatedAt = now()
    local saved, errorCode = CosmicVaultData.SetRecord(Entity(), RECORD_KEY, record)
    if not saved then return nil, errorCode end
    claimRecord = copy(record)
    applyPresentation()
    return true
end

local function requireRepair(reason, errorText)
    local working = copy(claimRecord or defaultRecord())
    working.revision = (working.revision or 0) + 1
    working.state = "repair_required"
    working.repairRequired = reason
    working.lastError = errorText or reason
    local saved, errorCode = persist(working)
    if not saved then
        claimRecord = working
        applyPresentation()
        print("[Cosmic Vault] Spatial Rift repair state could not persist: "
            .. tostring(errorCode))
    end
end

local function loadRecord()
    local record, errorCode = CosmicVaultData.GetRecord(Entity(), RECORD_KEY, SCHEMA_VERSION)
    if record then
        if not validRecord(record) then
            claimRecord = defaultRecord()
            claimRecord.state = "repair_required"
            claimRecord.repairRequired = "invalid_record"
            claimRecord.lastError = "invalid_record"
            return nil, "invalid_record"
        end
        claimRecord = record
        return record
    end
    if errorCode == "missing" then
        claimRecord = defaultRecord()
        if onServer() then
            local saved, saveError = persist(claimRecord)
            if not saved then return nil, saveError end
        end
        return claimRecord
    end

    claimRecord = defaultRecord()
    claimRecord.state = "repair_required"
    claimRecord.repairRequired = errorCode
    claimRecord.lastError = errorCode
    return nil, errorCode
end

local function rewardSeed(entityId)
    local hash = 17
    for i = 1, #entityId do
        hash = (hash * 131 + string.byte(entityId, i)) % 2147483647
    end
    return hash
end

local function prepareReward(receiverIndex, playerIndex)
    local entity = Entity()
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local seed = rewardSeed(entity.id.string)
    local random = Random(seed)
    local rewardFactor = Balancing_GetSectorRewardFactor(x, y)
    local bonusKind = "none"
    if random:getFloat() < 0.5 then
        bonusKind = random:getFloat() < 0.5 and "turret" or "upgrade"
    end

    local working = copy(claimRecord)
    working.revision = working.revision + 1
    working.state = "claim_prepared"
    working.claimantFaction = receiverIndex
    working.playerIndex = playerIndex
    working.rewardSeed = seed
    working.reward = {
        x = x,
        y = y,
        credits = math.floor(35000 * rewardFactor),
        resources = math.floor(2500 * rewardFactor),
        materialType = MaterialType.Ogonite,
        bonusKind = bonusKind,
        minimumRarity = RarityType.Exceptional
    }
    working.lastError = nil
    working.repairRequired = nil
    return working
end

local function materializeReward(record, receiver)
    local reward = record.reward
    local sector = Sector()
    local position = Entity().translationf

    sector:dropBundle(position, receiver, nil, reward.credits)
    sector:dropResources(position, receiver, nil, Material(reward.materialType),
        reward.resources)

    if reward.bonusKind == "turret" then
        local generator = SectorTurretGenerator()
        generator.minRarity = Rarity(reward.minimumRarity)
        local turret = generator:generate(reward.x, reward.y)
        if not turret then error("turret_generation_failed") end
        sector:dropTurret(position, receiver, nil, turret)
    elseif reward.bonusKind == "upgrade" then
        local generator = UpgradeGenerator()
        generator.minRarity = Rarity(reward.minimumRarity)
        local upgrade = generator:generateSectorSystem(reward.x, reward.y)
        if not upgrade then error("upgrade_generation_failed") end
        sector:dropUpgrade(position, receiver, nil, upgrade)
    end
end

function CvAnomalyRift.interactionPossible(playerIndex, option)
    if not claimRecord then loadRecord() end
    if claimRecord and claimRecord.state == "repair_required" then
        return false, "This rift's claim record requires administrator repair."%_t
    end
    if not claimRecord or claimRecord.state ~= "available" then return false end

    local player = Player(playerIndex)
    local craft = player and player.craft
    if not craft then return false end
    if craft:getNearestDistance(Entity()) < CvAnomalyRift.interactionDistance then return true end
    return false, "You're not close enough to channel the rift."%_t
end

function CvAnomalyRift.initialize()
    loadRecord()
    if onServer() and claimRecord and claimRecord.state == "claim_prepared" then
        requireRepair("interrupted_claim",
            "A prepared claim was restored without a verifiable completion receipt.")
    else
        applyPresentation()
    end
end

function CvAnomalyRift.initUI()
    if not claimRecord then loadRecord() end
    if claimRecord and claimRecord.state == "claimed" then return end
    local caption = claimRecord and claimRecord.state == "repair_required"
        and "Rift Claim Requires Repair"%_t or "Channel The Rift"%_t
    ScriptUI():registerInteraction(caption, "onChannelPressed", 8)
end

function CvAnomalyRift.onChannelPressed()
    if onClient() then
        invokeServerFunction("onChannelPressed")
        return
    end

    if not claimRecord then loadRecord() end
    if not claimRecord or claimRecord.state ~= "available" then return end

    local receiver, ship = getInteractingFaction(callingPlayer)
    if not receiver or not ship then return end
    if ship:getNearestDistance(Entity()) > CvAnomalyRift.interactionDistance then return end

    local prepared = prepareReward(receiver.index, callingPlayer)
    local saved, saveError = persist(prepared)
    if not saved then
        print("[Cosmic Vault] Spatial Rift claim preparation failed: " .. tostring(saveError))
        return
    end

    local materialized, materializeError = pcall(materializeReward, prepared, receiver)
    if not materialized then
        requireRepair("materialization_ambiguous", tostring(materializeError))
        return
    end

    local claimed = copy(prepared)
    claimed.revision = claimed.revision + 1
    claimed.state = "claimed"
    claimed.lastError = nil
    claimed.repairRequired = nil
    local completed, completeError = persist(claimed)
    if not completed then
        -- Loot may already exist. Never replay it when the completion receipt fails.
        requireRepair("completion_receipt_failed", tostring(completeError))
        return
    end

    terminate()
end

function CvAnomalyRift.secure()
    return copy(claimRecord)
end

function CvAnomalyRift.restore(data)
    local errorCode = select(2,
        CosmicVaultData.GetRecord(Entity(), RECORD_KEY, SCHEMA_VERSION))
    if errorCode == "missing" and validRecord(data) then
        claimRecord = copy(data)
        persist(claimRecord)
    else
        loadRecord()
    end
    if onServer() and claimRecord and claimRecord.state == "claim_prepared" then
        requireRepair("interrupted_claim",
            "A prepared claim was restored without a verifiable completion receipt.")
    else
        applyPresentation()
    end
end

callable(CvAnomalyRift, "onChannelPressed")
