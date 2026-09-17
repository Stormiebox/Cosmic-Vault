-- namespace CosmicVaultEnvironmentEffect
CosmicVaultEnvironmentEffect = {}

local EFFECT_CONTROLLER = "data/scripts/sector/cv_environment_controller.lua"
local runtime = {schemaVersion = 1, rootRevision = 0, x = 0, y = 0, conditions = {}}
local bonusKeys = {}

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[deepCopy(key)] = deepCopy(item) end
    return copy
end

local function clearBonuses()
    local entity = Entity()
    if entity then
        for _, key in ipairs(bonusKeys) do entity:removeBonus(key) end
    end
    bonusKeys = {}
end

local function applyBonuses()
    clearBonuses()
    local entity = Entity()
    if not entity then return end
    for _, condition in ipairs(runtime.conditions or {}) do
        local profile = condition.definition and condition.definition.mechanicsProfile
        if profile == "ion" then
            table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.HyperspaceCooldown, 10.0))
            table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.HyperspaceReach, -1.0))
            table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.RadarReach, -1.0))
        elseif profile == "dark_fog" then
            local faction = Faction(entity.factionIndex)
            local eclipse = faction and not faction.isPlayer and not faction.isAlliance
                and (faction.name == "The Eclipse" or faction:getValue("is_eclipse") == true)
            if not eclipse then
                table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.HyperspaceReach, -0.5))
                table.insert(bonusKeys, entity:addBaseMultiplier(StatsBonuses.RadarReach, -0.5))
            end
        end
    end
end

function CosmicVaultEnvironmentEffect.initialize(snapshot)
    if type(snapshot) == "table" then runtime = deepCopy(snapshot) end
    if onServer() then applyBonuses() end
end

function CosmicVaultEnvironmentEffect.reconcile(snapshot)
    if not onServer() or type(snapshot) ~= "table" or type(snapshot.conditions) ~= "table" then
        return nil, "invalid_snapshot"
    end
    runtime = deepCopy(snapshot)
    applyBonuses()
    if #runtime.conditions == 0 then terminate() end
    return runtime.rootRevision, nil
end

function CosmicVaultEnvironmentEffect.getUpdateInterval()
    return 5
end

function CosmicVaultEnvironmentEffect.updateServer(timeStep)
    if #runtime.conditions == 0 then
        terminate()
        return
    end
    local sector = Sector()
    if not sector or not sector:hasScript(EFFECT_CONTROLLER) then
        terminate()
        return
    end
    local ids = {}
    for _, condition in ipairs(runtime.conditions or {}) do table.insert(ids, condition.conditionId) end
    local status, present = sector:invokeFunction(EFFECT_CONTROLLER, "containsConditions", ids)
    if status == 0 and not present then terminate() end
end

function CosmicVaultEnvironmentEffect.secure()
    return deepCopy(runtime)
end

function CosmicVaultEnvironmentEffect.restore(data)
    if type(data) ~= "table" or type(data.conditions) ~= "table" then return end
    runtime = deepCopy(data)
    if onServer() then applyBonuses() end
end

function CosmicVaultEnvironmentEffect.onRemove()
    if onServer() then clearBonuses() end
end
