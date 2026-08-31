package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("galaxy")
include("faction")
include("callable")
local UpgradeGenerator = include("upgradegenerator")
local SectorTurretGenerator = include("sectorturretgenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CvAnomalyRift
CvAnomalyRift = {}
CvAnomalyRift.interactionDistance = 20

local harvested = false

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function CvAnomalyRift.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    local craft = player.craft
    if not craft then return false end

    local self = Entity()
    local dist = craft:getNearestDistance(self)
    if dist < CvAnomalyRift.interactionDistance then
        return true
    end

    return false, "You're not close enough to channel the rift."%_t
end

function CvAnomalyRift.initialize()
    -- The underlying entity is already flagged invincible by CosmicVaultAnomalies.spawnAnomaly
    -- when it creates this asteroid -- this is a permanent landmark, not a destructible object.
    Entity():setValue("valuable_object", RarityType.Exceptional)
end

-- create all required UI elements for the client side
function CvAnomalyRift.initUI()
    ScriptUI():registerInteraction("Channel The Rift"%_t, "onChannelPressed", 8)
end

function CvAnomalyRift.onChannelPressed()
    if onClient() then
        invokeServerFunction("onChannelPressed")
        return
    end

    if harvested then return end

    local receiver, ship = getInteractingFaction(callingPlayer)
    if not receiver then return end

    local self = Entity()
    local dist = ship:getNearestDistance(self)
    if dist > CvAnomalyRift.interactionDistance then return end

    harvested = true

    local sector = Sector()
    local x, y = sector:getCoordinates()
    local position = self.translationf
    local rewardFactor = Balancing_GetSectorRewardFactor(x, y)

    -- The rift bleeds exotic, high-tier matter -- a rarer payout than a standard wreck,
    -- reflecting how dangerous and uncommon these events are to trigger.
    sector:dropBundle(position, receiver, nil, math.floor(35000 * rewardFactor))
    sector:dropResources(position, receiver, nil, Material(MaterialType.Ogonite), math.floor(2500 * rewardFactor))

    -- 50% chance at a bonus turret or system upgrade materialized out of the rift.
    if random():getFloat() < 0.50 then
        if random():getFloat() < 0.5 then
            local tGen = SectorTurretGenerator()
            tGen.minRarity = Rarity(RarityType.Exceptional)
            local turret = tGen:generate(x, y)
            sector:dropTurret(position, receiver, nil, turret)
        else
            local uGen = UpgradeGenerator()
            uGen.minRarity = Rarity(RarityType.Exceptional)
            local upgrade = uGen:generateSectorSystem(x, y)
            sector:dropUpgrade(position, receiver, nil, upgrade)
        end
    end

    -- The rift itself stays behind as an inert, permanent landmark; only the one-time
    -- interaction and its detector tag are removed so it can't be channeled twice.
    self:setValue("valuable_object", nil)
    terminate()
end
callable(CvAnomalyRift, "onChannelPressed")
