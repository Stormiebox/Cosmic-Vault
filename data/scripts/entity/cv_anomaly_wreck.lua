package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("galaxy")
include("faction")
include("callable")
local UpgradeGenerator = include("upgradegenerator")
local SectorTurretGenerator = include("sectorturretgenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CvAnomalyWreck
CvAnomalyWreck = {}
CvAnomalyWreck.interactionDistance = 20

local salvaged = false

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function CvAnomalyWreck.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    local craft = player.craft
    if not craft then return false end

    local self = Entity()
    local dist = craft:getNearestDistance(self)
    if dist < CvAnomalyWreck.interactionDistance then
        return true
    end

    return false, "You're not close enough to salvage the wreck."%_t
end

function CvAnomalyWreck.initialize()
    Entity():setValue("valuable_object", RarityType.Exceptional)
end

-- create all required UI elements for the client side
function CvAnomalyWreck.initUI()
    ScriptUI():registerInteraction("Salvage Precursor Tech"%_t, "onSalvagePressed", 8)
end

function CvAnomalyWreck.onSalvagePressed()
    if onClient() then
        invokeServerFunction("onSalvagePressed")
        return
    end

    if salvaged then return end

    local receiver, ship = getInteractingFaction(callingPlayer)
    if not receiver then return end

    local self = Entity()
    local dist = ship:getNearestDistance(self)
    if dist > CvAnomalyWreck.interactionDistance then return end

    salvaged = true

    local sector = Sector()
    local x, y = sector:getCoordinates()
    local position = self.translationf
    local rewardFactor = Balancing_GetSectorRewardFactor(x, y)

    -- Bonus payout and salvaged Xanion, matching the tier of hull the wreck itself was
    -- generated from (see CosmicVaultAnomalies.spawnAnomaly's PrecursorWreck branch).
    sector:dropBundle(position, receiver, nil, math.floor(25000 * rewardFactor))
    sector:dropResources(position, receiver, nil, Material(MaterialType.Xanion), math.floor(4000 * rewardFactor))

    -- 40% chance at a bonus turret or system upgrade salvaged from the wreck's core.
    if random():getFloat() < 0.40 then
        if random():getFloat() < 0.5 then
            local tGen = SectorTurretGenerator()
            tGen.minRarity = Rarity(RarityType.Rare)
            local turret = tGen:generate(x, y)
            sector:dropTurret(position, receiver, nil, turret)
        else
            local uGen = UpgradeGenerator()
            uGen.minRarity = Rarity(RarityType.Rare)
            local upgrade = uGen:generateSectorSystem(x, y)
            sector:dropUpgrade(position, receiver, nil, upgrade)
        end
    end

    -- Leave the hull itself in place as salvageable wreckage; only remove the bonus
    -- interaction and its detector tag so the wreck can't be looted twice.
    self:setValue("valuable_object", nil)
    terminate()
end
callable(CvAnomalyWreck, "onSalvagePressed")
