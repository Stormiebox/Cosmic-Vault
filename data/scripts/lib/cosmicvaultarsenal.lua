
include("cosmicvaultframework")
include("weapontype")

-- namespace CosmicVaultArsenal
CosmicVaultArsenal = CosmicVaultArsenal or {}

-- These are the exact dispatch keys registered by vanilla turretgenerator.lua.
local supportedWeaponTypes = {
    [WeaponType.ChainGun] = true,
    [WeaponType.PointDefenseChainGun] = true,
    [WeaponType.PointDefenseLaser] = true,
    [WeaponType.Laser] = true,
    [WeaponType.MiningLaser] = true,
    [WeaponType.RawMiningLaser] = true,
    [WeaponType.SalvagingLaser] = true,
    [WeaponType.RawSalvagingLaser] = true,
    [WeaponType.PlasmaGun] = true,
    [WeaponType.RocketLauncher] = true,
    [WeaponType.Cannon] = true,
    [WeaponType.RailGun] = true,
    [WeaponType.RepairBeam] = true,
    [WeaponType.Bolter] = true,
    [WeaponType.LightningGun] = true,
    [WeaponType.TeslaGun] = true,
    [WeaponType.ForceGun] = true,
    [WeaponType.PulseCannon] = true,
    [WeaponType.AntiFighter] = true
}

--[[
    Cosmic Vault Arsenal API
    Provides mathematical generators to spit out properly balanced, custom Weapon/InventoryTurret
    objects dynamically for loot drops, custom enemies, or missions.
]]

--- Generates a custom turret based on a configuration table
-- @param config (table) Turret generation parameters
-- @return (TurretTemplate) The generated turret
function CosmicVaultArsenal.GenerateTurret(config)
    if type(config) ~= 'table' then return end
    --[[
        config table structure:
        {
            rarity = Rarity(RarityType.Rare),
            material = Material(MaterialType.Titanium),
            weaponType = WeaponType.Bolter,
            damage = 150,
            fireRate = 2.0,
            range = 8000,
            accuracy = 0.95,
            energyIncrease = 0,
            coaxial = false,
            color = ColorRGB(1, 0, 0),
            size = 1.0,
            slots = 2
        }
    ]]

    -- turret.rarity/turret.material/turret.weaponName are all read-only on
    -- InventoryTurret (writes are silently discarded) - rarity and material
    -- are actually set on the Weapon object below, which does have writable
    -- rarity/material fields. Note: Weapon() takes no constructor argument
    -- (vanilla always calls it bare and configures the weapon's identity via
    -- Weapon:setProjectile()/:setBeam() plus manual physics fields), so
    -- config.weaponType currently has no effect on the generated weapon's
    -- actual type - it is not wired up to anything the engine reads.
    local turret = InventoryTurret()
    turret.coaxial = config.coaxial or false
    turret.size = config.size or 1.0
    turret.slots = config.slots or 1

    local weapon = Weapon()
    weapon.rarity = config.rarity or Rarity(RarityType.Common)
    weapon.material = config.material or Material(MaterialType.Iron)
    weapon.damage = config.damage or 10
    weapon.fireRate = config.fireRate or 5
    weapon.reach = config.range or 5000
    weapon.accuracy = config.accuracy or 0.9
    weapon.pcolor = config.color or ColorRGB(1,1,1)

    if config.energyIncrease and config.energyIncrease > 0 then
        weapon.energyIncreasePerSecond = config.energyIncrease
    end

    turret:clearWeapons()
    turret:addWeapon(weapon)

    -- Crew:add() takes a CrewMan (a crew member instance), not a bare CrewProfession
    -- (which only describes the profession's stats/name, not an actual crewman) -
    -- every vanilla call site (turretgenerator.lua included) constructs a CrewMan.
    local crew = Crew()
    crew:add(math.max(1, math.floor(turret.slots * 1.5)), CrewMan(CrewProfessionType.Gunner))
    turret.crew = crew

    -- Re-evaluate to lock in stats
    -- turret:updateStaticAttributes() -- Removed: improperly used method

    return turret
end

--- Generates a seeded turret through vanilla's weapon-type dispatcher.
-- @param config (table) Typed generation parameters
-- @return (TurretTemplate|nil, string|nil) Generated turret or an error code
function CosmicVaultArsenal.GenerateTypedTurret(config)
    if type(config) ~= "table" then return nil, "invalid_config" end
    if not supportedWeaponTypes[config.weaponType] then return nil, "unsupported_weapon_type" end
    if config.seed == nil then return nil, "missing_seed" end
    if type(config.dps) ~= "number" or config.dps <= 0 then return nil, "invalid_dps" end
    if type(config.tech) ~= "number" or config.tech < 0 then return nil, "invalid_tech" end
    if config.rarity == nil then return nil, "missing_rarity" end
    if config.material == nil then return nil, "missing_material" end
    if config.coaxialAllowed ~= nil and type(config.coaxialAllowed) ~= "boolean" then
        return nil, "invalid_coaxial_allowed"
    end
    if config.title ~= nil and type(config.title) ~= "string" then return nil, "invalid_title" end
    if config.icon ~= nil and type(config.icon) ~= "string" then return nil, "invalid_icon" end
    if config.size ~= nil and (type(config.size) ~= "number" or config.size <= 0) then
        return nil, "invalid_size"
    end
    if config.slots ~= nil and (type(config.slots) ~= "number" or config.slots < 1) then
        return nil, "invalid_slots"
    end

    local TurretGenerator = include("turretgenerator")
    if not TurretGenerator or type(TurretGenerator.generateSeeded) ~= "function" then
        return nil, "generator_unavailable"
    end

    local generated, turret = pcall(
        TurretGenerator.generateSeeded,
        config.seed,
        config.weaponType,
        config.dps,
        config.tech,
        config.rarity,
        config.material,
        config.coaxialAllowed)
    if not generated or not turret then return nil, "generation_failed" end

    if config.title ~= nil then turret.title = config.title end
    if config.icon ~= nil then turret.icon = config.icon end
    if config.size ~= nil then turret.size = config.size end
    if config.slots ~= nil then turret.slots = math.floor(config.slots) end

    return turret, nil
end

--- Spawns a turret drop in the sector
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param template (TurretTemplate) The turret template
function CosmicVaultArsenal.SpawnLootTurret(sector, x, y, z, config)
    if not x or not y or type(config) ~= "table" then return end
    local turret = CosmicVaultArsenal.GenerateTurret(config)
    sector:dropTurret(vec3(x, y, z), nil, nil, turret)
    return turret
end

--- Spawns a system upgrade drop in the sector
-- @param sector (Sector) The sector object
-- @param x, y, z (number) Coordinates
-- @param scriptPath (string) The path to the upgrade script
-- @param rarity (Rarity) The rarity of the upgrade
function CosmicVaultArsenal.SpawnLootUpgrade(sector, x, y, z, scriptPath, rarity)
    if not sector or not scriptPath then return end
    local upgrade = SystemUpgradeTemplate(scriptPath, rarity or Rarity(RarityType.Common), random():createSeed())
    sector:dropUpgrade(vec3(x, y, z), nil, nil, upgrade)
    return upgrade
end

if CosmicVaultFramework and CosmicVaultFramework.registerModule then
    CosmicVaultFramework.registerModule("CosmicVaultArsenal", {version = "1.0.0"})
end

return CosmicVaultArsenal
