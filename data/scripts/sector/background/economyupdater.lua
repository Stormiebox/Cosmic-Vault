
include("callable")
include("randomext")
local FactoryMap = include("factorymap")
local SectorGenerator = include("SectorGenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EconomyUpdater
EconomyUpdater = {}
local self = EconomyUpdater
self.supply = nil
self.demand = nil
self.sum = nil
self.waitingForRefresh = false

function EconomyUpdater.getUpdateInterval()
    if onClient() and not self.supply and not self.demand and not self.sum then
        return 5
    end

    return 300
end

function EconomyUpdater.initialize()
    self.map = FactoryMap()

    if onServer() then
        self.refresh()
        Sector():registerCallback("onEntityCreated", "onEntityCreated")
    end

    if onClient() then
        EconomyUpdater.requestData()
    end
end

function EconomyUpdater.updateClient(timeStep)
    if not self.supply and not self.demand and not self.sum then
        EconomyUpdater.requestData()
    end
end

function EconomyUpdater.updateServer(timeStep)
    self.refresh()

    -- Cosmic Chronicles/Vault: Vault Economy + Chronicles (Famine Relief Anomalies)
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local factionIndex = Galaxy():getControllingFaction(x, y)

    if factionIndex then
        local cve = include("cosmicvaulteconomy")
        if cve and cve.getFamineScore then
            local score = cve.getFamineScore(factionIndex)
            if type(score) == "number" and score >= 100 then
                -- 1% chance to spawn a Famine Relief Cache in a starving sector
                if random():test(0.01) then
                    local generator = SectorGenerator(x, y)
                    local beacon = generator:createBeacon(generator:getPositionInSector(), Faction(factionIndex), "EMERGENCY RELIEF CACHE")
                    if beacon then
                        beacon.title = "Famine Relief Cache"
                        -- cc_blackbox.lua only exists in Cosmic Chronicles; Cosmic
                        -- Vault has no dependencies and must keep working without
                        -- it, so this attach is best-effort only.
                        pcall(function() beacon:addScriptOnce("data/scripts/entity/cc_blackbox.lua") end)
                        beacon:setValue("is_famine_relief", factionIndex)
                    end
                end
            end
        end
    end
end

function EconomyUpdater.onEntityCreated(id)
    local entity = Entity(id)
    if not entity then return end

    if entity.type == EntityType.Station then
        self.scheduleRefresh()
    end
end

function EconomyUpdater.scheduleRefresh()
    if self.waitingForRefresh then return end
    self.waitingForRefresh = true

    deferredCallback(5, "deferredRefresh")
end

function EconomyUpdater.deferredRefresh()
    self.waitingForRefresh = false
    self.refresh()
end

function EconomyUpdater.refresh()
    self.map:refreshCurrentSector()

    local code = [[
    package.path = package.path .. ";data/scripts/lib/?.lua"
    package.path = package.path .. ";data/scripts/?.lua"

    local FactoryMap = include("factorymap")

    function run(x, y)
        local map = FactoryMap()
        local supply, demand, sum = map:getSupplyAndDemand(x, y)
        return supply, demand, sum
    end
    ]]

    local x, y = Sector():getCoordinates()
    async("onEconomyRefreshDone", code, x, y)
end

function EconomyUpdater.immediateRefresh()
    self.map:refreshCurrentSector()

    local x, y = Sector():getCoordinates()
    local supply, demand, sum = self.map:getSupplyAndDemand(x, y)
    self.supply = supply
    self.demand = demand
    self.sum = sum
end

function EconomyUpdater.onEconomyRefreshDone(supply, demand, sum)
    self.supply = supply
    self.demand = demand
    self.sum = sum

    broadcastInvokeClientFunction("setData", self.supply, self.demand)
end

function EconomyUpdater.requestData()
    if onClient() then
        invokeServerFunction("requestData")
        return
    end

    if callingPlayer and self.supply and self.demand then
        invokeClientFunction(Player(callingPlayer), "setData", self.supply, self.demand)
    end
end
callable(EconomyUpdater, "requestData")

function EconomyUpdater.setData(supply, demand)
    if type(supply) ~= "table" then supply = {} end
    if type(demand) ~= "table" then demand = {} end

    self.supply = supply
    self.demand = demand
    self.sum = {}

    local sum = self.sum
    for good, value in pairs(supply) do
        if type(good) == "string" and type(value) == "number" then
            sum[good] = value
        end
    end

    for good, value in pairs(demand) do
        if type(good) == "string" and type(value) == "number" then
            sum[good] = (sum[good] or 0) - value
        end
    end
end

function EconomyUpdater.getSupplyDemandPriceChange(good, ownSupplyType)
    if type(good) ~= "string" then return 0 end
    if not self.sum then return 0 end

    local sum = self.sum[good]
    if not sum then return 0 end


    if ownSupplyType then
        local influence = self.map.SupplyInfluence[ownSupplyType] or 0
        if ownSupplyType == self.map.SupplyType.FactorySupply
                or ownSupplyType == self.map.SupplyType.FactoryDemand then
            influence = influence * 1.25
        end

        sum = sum - influence
    end

    local factor = self.map:supplyToPriceChange(sum) or 0

    -- COSMIC VAULT CUSTOM ECONOMY ENGINE HOOK
    if onServer() then
        local key = "CVE_PriceHook_" .. good:gsub("%s+", "_")
        local hooksStr = Server():getValue(key)

        if type(hooksStr) == "string" then
            for hook in string.gmatch(hooksStr, "([^|]+)") do
                local scriptName, functionName = string.match(hook, "([^:]+)::([^:]+)")
                if scriptName and functionName then
                    -- First try invoking the hook on the Sector
                    local ok, extraFactor = Sector():invokeFunction(scriptName, functionName, good, factor)

                    if ok == 0 and type(extraFactor) == "number" then
                        factor = factor * extraFactor
                    else
                        local ok2, extraFactor2 = Galaxy():invokeFunction(scriptName, functionName, good, factor)
                        if ok2 == 0 and type(extraFactor2) == "number" then
                            factor = factor * extraFactor2
                        end
                    end
                end
            end
        end
    end

    return factor
end

