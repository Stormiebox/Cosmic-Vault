include("randomext")

-- namespace CosmicVaultEnvironmentController
CosmicVaultEnvironmentController = {}

local WeatherDictionary = include("cosmicvaultweatherdictionary")

local EFFECT_SCRIPT = "data/scripts/entity/cv_environment_effect.lua"
local runtime = {schemaVersion = 1, rootRevision = 0, x = 0, y = 0, conditions = {}}
local warnedPlayers = {}
local clientProblemKeys = {}
local clientSnapshot = {conditions = {}}
local visualTimer = 0
local soundTimer = 0
local nextSoundAt = 12
local lastExpiryRevision = -1

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[deepCopy(key, seen)] = deepCopy(item, seen) end
    return copy
end

local function conditionIds(conditions)
    local ids = {}
    for _, condition in ipairs(conditions or {}) do table.insert(ids, condition.conditionId) end
    table.sort(ids)
    return ids
end

local function validSnapshot(snapshot)
    if type(snapshot) ~= "table" or snapshot.schemaVersion ~= 1 then return false end
    if type(snapshot.rootRevision) ~= "number" or type(snapshot.x) ~= "number"
            or type(snapshot.y) ~= "number" or type(snapshot.conditions) ~= "table" then
        return false
    end
    local seen = {}
    for _, condition in ipairs(snapshot.conditions) do
        local definition = type(condition) == "table" and condition.definition or nil
        if type(condition) ~= "table" or type(condition.conditionId) ~= "string"
                or type(condition.revision) ~= "number" or type(condition.definition) ~= "table"
                or condition.x ~= snapshot.x or condition.y ~= snapshot.y
                or type(condition.weatherType) ~= "string"
                or type(definition.name) ~= "string"
                or type(definition.detailedName) ~= "string"
                or type(definition.description) ~= "string"
                or type(definition.icon) ~= "string"
                or type(definition.presentationProfile) ~= "string"
                or type(definition.mechanicsProfile) ~= "string"
                or type(definition.color) ~= "table"
                or type(definition.color.r) ~= "number"
                or type(definition.color.g) ~= "number"
                or type(definition.color.b) ~= "number"
                or seen[condition.conditionId] then
            return false
        end
        seen[condition.conditionId] = true
    end
    return true
end

local function mechanicalConditions()
    local result = {}
    for _, condition in ipairs(runtime.conditions) do
        local profile = condition.definition and condition.definition.mechanicsProfile
        if profile == "ion" or profile == "dark_fog" then
            table.insert(result, deepCopy(condition))
        end
    end
    return result
end

local function effectSnapshot()
    return {
        schemaVersion = 1,
        rootRevision = runtime.rootRevision,
        x = runtime.x,
        y = runtime.y,
        conditions = mechanicalConditions()
    }
end

local function applyEffectsToShips(ships)
    local snapshot = effectSnapshot()
    for _, ship in ipairs(ships) do
        if valid(ship) and ship.isShip then
            if #snapshot.conditions > 0 then
                if ship:hasScript(EFFECT_SCRIPT) then
                    ship:invokeFunction(EFFECT_SCRIPT, "reconcile", snapshot)
                else
                    ship:addScriptOnce(EFFECT_SCRIPT, snapshot)
                end
            elseif ship:hasScript(EFFECT_SCRIPT) then
                ship:invokeFunction(EFFECT_SCRIPT, "reconcile", snapshot)
            end
        end
    end
end

local function playerSnapshot(player)
    local snapshot = deepCopy(runtime)
    local craft = player and player.craft
    snapshot.solarPrepared = false
    if craft then
        for _, condition in ipairs(runtime.conditions) do
            if condition.definition.mechanicsProfile == "solar" then
                snapshot.solarPrepared = WeatherDictionary.getSolarPreparation(craft)
                break
            end
        end
    end
    return snapshot
end

local function warnPlayer(player, reason)
    if not player then return end
    for _, condition in ipairs(runtime.conditions) do
        local warned = warnedPlayers[condition.conditionId]
        if not warned then
            warned = {}
            warnedPlayers[condition.conditionId] = warned
        end
        if not warned[player.index] and reason ~= "refreshed" then
            local warning = condition.definition and condition.definition.chatWarning
            if type(warning) == "string" and warning ~= "" then
                player:sendChatMessage("Environmental Alert", ChatMessageType.Warning, warning)
            end
            warned[player.index] = true
        end
    end
end

local function synchronizePlayer(player, reason)
    if not player then return end
    invokeClientFunction(player, "receiveSnapshot", playerSnapshot(player))
    warnPlayer(player, reason)
end

local function synchronizePlayers(reason)
    for _, player in pairs({Sector():getPlayers()}) do synchronizePlayer(player, reason) end
end

function CosmicVaultEnvironmentController.initialize()
    local sector = Sector()
    if not sector then return end
    runtime.x, runtime.y = sector:getCoordinates()
    if onServer() then
        sector:registerCallback("onEntityEntered", "onEntityEntered")
        sector:registerCallback("onPlayerEntered", "onPlayerEntered")
        sector:registerCallback("onPlayerLeft", "onPlayerLeft")
    end
end

function CosmicVaultEnvironmentController.reconcile(snapshot, reason)
    if not onServer() then return nil, "client_context" end
    if not validSnapshot(snapshot) then return nil, "invalid_snapshot" end
    local sector = Sector()
    if not sector then return nil, "sector_unavailable" end
    local x, y = sector:getCoordinates()
    if snapshot.x ~= x or snapshot.y ~= y then return nil, "coordinate_mismatch" end
    if snapshot.rootRevision < runtime.rootRevision then return nil, "stale_snapshot" end

    runtime = deepCopy(snapshot)

    local activeIds = {}
    for _, condition in ipairs(runtime.conditions) do activeIds[condition.conditionId] = true end
    for conditionId in pairs(warnedPlayers) do
        if not activeIds[conditionId] then warnedPlayers[conditionId] = nil end
    end

    local ships = {sector:getEntitiesByType(EntityType.Ship)}
    applyEffectsToShips(ships)
    synchronizePlayers(reason or "reconciled")

    if reason == "expired" and lastExpiryRevision ~= runtime.rootRevision then
        lastExpiryRevision = runtime.rootRevision
        for _, player in pairs({sector:getPlayers()}) do
            player:sendChatMessage("Environmental Alert", ChatMessageType.Information,
                "A local environmental condition has subsided.")
        end
    end

    return runtime.rootRevision, conditionIds(runtime.conditions)
end

function CosmicVaultEnvironmentController.onEntityEntered(entityId)
    if not onServer() then return end
    local entity = Entity(entityId)
    if entity and entity.isShip then applyEffectsToShips({entity}) end
end

function CosmicVaultEnvironmentController.onPlayerEntered(playerIndex)
    if not onServer() then return end
    synchronizePlayer(Player(playerIndex), "entered")
end

function CosmicVaultEnvironmentController.onPlayerLeft(playerIndex)
    if not onServer() then return end
    for _, warned in pairs(warnedPlayers) do warned[playerIndex] = nil end
end

function CosmicVaultEnvironmentController.containsConditions(ids)
    if type(ids) ~= "table" then return false end
    local present = {}
    for _, condition in ipairs(runtime.conditions) do present[condition.conditionId] = true end
    for _, id in ipairs(ids) do
        if not present[id] then return false end
    end
    return true
end

function CosmicVaultEnvironmentController.getUpdateInterval()
    return 5
end

function CosmicVaultEnvironmentController.updateServer(timeStep)
    local sector = Sector()
    if not sector then return end
    local ships = {sector:getEntitiesByType(EntityType.Ship)}
    local solarActive = false
    for _, condition in ipairs(runtime.conditions) do
        if condition.definition.mechanicsProfile == "solar" then
            solarActive = true
            break
        end
    end
    if not solarActive then return end

    for _, ship in ipairs(ships) do
        if valid(ship) and ship.isShip and not WeatherDictionary.isEclipse(ship) then
            local maxShield = ship.shieldMaxDurability or 0
            local currentShield = ship.shieldDurability or 0
            if currentShield > 0 then
                ship:inflictDamage(math.min(currentShield, maxShield * 0.02), DamageSource.Arbitrary,
                    DamageType.Energy, 0, vec3(), ship.id)
            else
                local _, physicalMultiplier = WeatherDictionary.getSolarPreparation(ship)
                local maxHull = ship.maxDurability or 0
                ship:inflictDamage(maxHull * 0.005 * physicalMultiplier, DamageSource.Arbitrary,
                    DamageType.Physical, 0, vec3(), ship.id)
            end
        end
    end
end

local function problemKey(conditionId)
    return "CosmicVaultEnvironment:" .. conditionId
end

local function removeClientProblems()
    for key in pairs(clientProblemKeys) do removeSectorProblem(key) end
    clientProblemKeys = {}
end

function CosmicVaultEnvironmentController.receiveSnapshot(snapshot)
    if not onClient() or not validSnapshot(snapshot) then return end
    removeClientProblems()
    clientSnapshot = deepCopy(snapshot)
    for _, condition in ipairs(clientSnapshot.conditions) do
        local definition = condition.definition
        local tooltip = definition.detailedName .. "\n\n" .. definition.description
        if definition.mechanicsProfile == "solar" then
            if clientSnapshot.solarPrepared then
                tooltip = tooltip .. "\n\nTrinium-heavy hull protection: active (physical damage halved)."
            else
                tooltip = tooltip .. "\n\nTrinium-heavy hull protection: inactive."
            end
        end
        local key = problemKey(condition.conditionId)
        addSectorProblem(key, tooltip, definition.icon,
            ColorRGB(definition.color.r, definition.color.g, definition.color.b), true)
        clientProblemKeys[key] = true
    end
end

local function playerPosition()
    local player = Player()
    local craft = player and player.craft
    return craft and craft.translationf, craft
end

local function playThunder(position)
    local sounds = {"distant-thunder1", "distant-thunder2", "distant-thunder3", "distant-thunder4"}
    play3DSound(randomEntry(sounds), SoundType.Other,
        position + random():getDirection() * 10000, 200000, 1)
end

function CosmicVaultEnvironmentController.updateClient(timeStep)
    visualTimer = visualTimer + timeStep
    soundTimer = soundTimer + timeStep
    if visualTimer < 1.5 then return end
    visualTimer = 0
    local position, craft = playerPosition()
    if not position then return end
    local sector = Sector()
    if not sector then return end

    local wantsThunder = false
    for _, condition in ipairs(clientSnapshot.conditions or {}) do
        local definition = condition.definition
        local profile = definition.presentationProfile
        local color = ColorRGB(definition.color.r, definition.color.g, definition.color.b)
        local effectPosition = position + random():getDirection() * random():getFloat(80, 350)
        if profile == "ion" or profile == "rift" then
            sector:createSpark(effectPosition, random():getDirection() * 10, 3, 1.2, color, 0.3, craft)
            sector:createGlow(effectPosition, random():getFloat(8, 20), color)
            wantsThunder = true
        elseif profile == "solar" then
            sector:createGlow(effectPosition, random():getFloat(12, 30), color)
            sector:createDust(effectPosition, random():getFloat(2, 5), color, 2)
        elseif profile == "fog" then
            sector:createDust(effectPosition, random():getFloat(4, 9), color, 4)
            wantsThunder = true
        end
    end

    if wantsThunder and soundTimer >= nextSoundAt then
        playThunder(position)
        soundTimer = 0
        nextSoundAt = random():getFloat(12, 30)
    end
end

function CosmicVaultEnvironmentController.secure()
    return deepCopy(runtime)
end

function CosmicVaultEnvironmentController.restore(data)
    if validSnapshot(data) then
        runtime = deepCopy(data)
        if onClient() then CosmicVaultEnvironmentController.receiveSnapshot(runtime) end
    end
end

function CosmicVaultEnvironmentController.onRemove()
    if onClient() then removeClientProblems() end
end
