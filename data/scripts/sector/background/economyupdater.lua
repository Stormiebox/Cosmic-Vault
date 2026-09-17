
include("callable")
local FactoryMap = include("factorymap")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EconomyUpdater
EconomyUpdater = {}
local self = EconomyUpdater
self.supply = nil
self.demand = nil
self.sum = nil
self.marketEvents = {}
self.waitingForRefresh = false

function EconomyUpdater.getUpdateInterval()
    if onClient() then return self.sum and 30 or 5 end

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
    for _, event in ipairs(self.marketEvents or {}) do
        event.remaining = math.max(0, (event.remaining or 0) - timeStep)
    end
    if not self.supply and not self.demand and not self.sum then
        EconomyUpdater.requestData()
    else
        -- Market events can begin or end between the five-minute supply refreshes.
        EconomyUpdater.requestData()
    end
end

local function marketEventsForCurrentSector()
    if not onServer() then return {} end
    local CosmicVaultData = include("cosmicvaultdata")
    local record = CosmicVaultData.GetRecord(Server(), "cv_market_events_v1", 1)
    if not record or type(record.events) ~= "table" then return {} end
    local x, y = Sector():getCoordinates()
    local currentTime = Server().unpausedRuntime
    local events = {}
    for _, event in pairs(record.events) do
        if event.state == "active" and type(event.expiresAt) == "number"
                and event.expiresAt > currentTime and type(event.x) == "number"
                and type(event.y) == "number" and type(event.radius) == "number"
                and type(event.goodName) == "string" and type(event.priceDelta) == "number" then
            local dx, dy = x - event.x, y - event.y
            if dx * dx + dy * dy <= event.radius * event.radius then
                table.insert(events, {
                    eventId = event.eventId,
                    goodName = event.goodName,
                    priceDelta = event.priceDelta,
                    remaining = event.expiresAt - currentTime
                })
            end
        end
    end
    return events
end

function EconomyUpdater.updateServer(timeStep)
    self.refresh()
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

    broadcastInvokeClientFunction("setData", self.supply, self.demand,
        marketEventsForCurrentSector())
end

function EconomyUpdater.requestData()
    if onClient() then
        invokeServerFunction("requestData")
        return
    end

    if callingPlayer and self.supply and self.demand then
        invokeClientFunction(Player(callingPlayer), "setData", self.supply, self.demand,
            marketEventsForCurrentSector())
    end
end
callable(EconomyUpdater, "requestData")

function EconomyUpdater.setData(supply, demand, marketEvents)
    if type(supply) ~= "table" then supply = {} end
    if type(demand) ~= "table" then demand = {} end

    self.supply = supply
    self.demand = demand
    self.marketEvents = type(marketEvents) == "table" and marketEvents or {}
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

    local sum = self.sum[good] or 0


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

        local sector = Sector()
        local x, y = sector:getCoordinates()
        local economy = include("cosmicvaulteconomy")
        if economy and economy.GetMarketPriceDelta then
            local eventDelta = economy.GetMarketPriceDelta(good, x, y, Server().unpausedRuntime)
            if type(eventDelta) == "number" then factor = factor + eventDelta end
        end
    else
        for _, event in ipairs(self.marketEvents or {}) do
            if (event.remaining or 0) > 0
                    and (event.goodName == "All" or event.goodName == good)
                    and type(event.priceDelta) == "number" then
                factor = factor + event.priceDelta
            end
        end
    end

    return math.max(-0.30, math.min(0.30, factor))
end


