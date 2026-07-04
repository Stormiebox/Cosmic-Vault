package.path = package.path .. ";data/scripts/lib/?.lua"
local PlanGenerator = include("plangenerator")
local ShipUtility = include("shiputility")

-- namespace CosmicVaultBlueprint
CosmicVaultBlueprint = {}

--- Spawns a custom ship from an XML string or file natively
-- @param factionId (int) The faction index to own the ship
-- @param xmlPlan (string) The XML string or absolute file path to the plan
-- @param matrix (Matrix) The spawn coordinates and rotation
-- @param volume (number) Optional. If provided, scales the plan to this volume
-- @return Entity The spawned ship entity
function CosmicVaultBlueprint.spawnShip(factionId, xmlPlan, matrix, volume)
    if not onServer() then return end
    
    local faction = Faction(factionId)
    if not faction then return end
    
    local plan = BlockPlan()
    local success = pcall(function() plan = LoadPlanFromString(xmlPlan) end)
    if not success or not plan or plan.numBlocks == 0 then
        -- Try loading as a file path if string parsing failed or was empty
        pcall(function() plan = LoadPlanFromFile(xmlPlan) end)
    end
    
    if not plan or plan.numBlocks == 0 then return nil end

    if volume and volume > 0 then
        plan:scale(math.pow(volume / plan.volume, 1 / 3))
    end

    local sector = Sector()
    if not sector then return nil end
    local ship = sector:createShip(faction, "", plan, matrix or Matrix())
    
    -- Assign native crew and captain so the ship isn't a dead husk
    ShipUtility.addMinimumCrew(ship, 1.5)
    
    local captain = Captain()
    captain.name = "Commander"
    captain.tier = 1
    ship:setCaptain(captain)
    
    return ship
end

--- Spawns a custom station from an XML string or file natively
-- @param factionId (int) The faction index to own the station
-- @param xmlPlan (string) The XML string or absolute file path to the plan
-- @param matrix (Matrix) The spawn coordinates and rotation
-- @param stationType (string) Optional. Defaults to "data/scripts/entity/station.lua"
-- @return Entity The spawned station entity
function CosmicVaultBlueprint.spawnStation(factionId, xmlPlan, matrix, stationType)
    if not onServer() then return end
    
    local faction = Faction(factionId)
    if not faction then return end
    
    local plan = BlockPlan()
    local success = pcall(function() plan = LoadPlanFromString(xmlPlan) end)
    if not success or not plan or plan.numBlocks == 0 then
        pcall(function() plan = LoadPlanFromFile(xmlPlan) end)
    end
    
    if not plan or plan.numBlocks == 0 then return nil end

    local sector = Sector()
    if not sector then return nil end
    local station = sector:createStation(faction, plan, matrix or Matrix(), "")
    
    if stationType then
        station:addScriptOnce(stationType)
    else
        station:addScriptOnce("data/scripts/entity/station.lua")
    end
    
    ShipUtility.addMinimumCrew(station, 2.0)
    
    return station
end

--- Creates an InventoryTurret object from a custom turret XML plan
-- @param xmlPlan (string) The XML string of the custom turret
-- @param weaponType (int) The WeaponType to assign
-- @param rarity (Rarity) The rarity of the turret
-- @param material (Material) The material of the turret
-- @return InventoryTurret The generated custom turret item
function CosmicVaultBlueprint.createTurretFromPlan(xmlPlan, weaponType, rarity, material)
    local plan = BlockPlan()
    local success = pcall(function() plan = LoadPlanFromString(xmlPlan) end)
    if not success or not plan or plan.numBlocks == 0 then return nil end
    
    local turret = InventoryTurret()
    turret.weaponPrefix = weaponType or WeaponType.ChainGun
    turret.rarity = rarity or Rarity(RarityType.Common)
    turret.material = material or Material(MaterialType.Iron)
    turret.customTurretDesign = plan
    
    return turret
end

return CosmicVaultBlueprint
