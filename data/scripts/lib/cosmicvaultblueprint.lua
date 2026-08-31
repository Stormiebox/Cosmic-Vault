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
    if type(factionId) ~= "number" then return nil end
    if type(xmlPlan) ~= "string" then return nil end
    if matrix and type(matrix) ~= "userdata" then return nil end
    if volume and type(volume) ~= "number" then return nil end
    
    local faction = Faction(factionId)
    if not faction then return end
    
    local plan = LoadPlanFromString(xmlPlan)
    if not plan or plan.numBlocks == 0 then
        -- Try loading as a file path if string parsing failed or was empty
        plan = LoadPlanFromFile(xmlPlan)
    end
    
    if not plan or plan.numBlocks == 0 then return nil end

    if volume and volume > 0 and plan.volume > 0 then
        -- BlockPlan:scale() takes a vec3, not a plain number - a bare number
        -- here throws immediately, crashing every caller that passes volume.
        plan:scale(vec3(math.pow(volume / plan.volume, 1 / 3)))
    end

    local sector = Sector()
    if not sector then return nil end
    local ship = sector:createShip(faction, "", plan, matrix or Matrix())

    -- Assign native crew and captain so the ship isn't a dead husk.
    -- ShipUtility has no "addMinimumCrew" function; Entity.minCrew is the
    -- engine's own computed minimum crew for this exact plan.
    ship.crew = ship.minCrew

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
    if type(factionId) ~= "number" then return nil end
    if type(xmlPlan) ~= "string" then return nil end
    if matrix and type(matrix) ~= "userdata" then return nil end
    if stationType and type(stationType) ~= "string" then return nil end
    
    local faction = Faction(factionId)
    if not faction then return end
    
    local plan = LoadPlanFromString(xmlPlan)
    if not plan or plan.numBlocks == 0 then
        plan = LoadPlanFromFile(xmlPlan)
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
    
    station.crew = station.minCrew

    return station
end

--- Creates an InventoryTurret object from a custom turret XML plan
-- NOT IMPLEMENTED: InventoryTurret.rarity/.material/.weaponPrefix are all
-- read-only (per Avorion Stubs/InventoryTurret.lua) and there is no
-- "customTurretDesign" field, or any other documented way to attach a block
-- Plan as a turret's visual model, anywhere in the stubs or vanilla source.
-- Returning a turret here would silently ignore every argument and hand back
-- an unconfigured default - use CosmicVaultArsenal.GenerateTurret() instead,
-- or Sector():dropTurret() with a generated TurretTemplate.
-- @return nil Always. Kept only so existing include() call sites don't error.
function CosmicVaultBlueprint.createTurretFromPlan(xmlPlan, weaponType, rarity, material)
    include("cosmicvaultdebug").error("CosmicVaultBlueprint", "createTurretFromPlan() is not implemented - Avorion exposes no way to build an InventoryTurret from a custom XML block Plan. Use CosmicVaultArsenal.GenerateTurret() instead.")
    return nil
end

return CosmicVaultBlueprint
