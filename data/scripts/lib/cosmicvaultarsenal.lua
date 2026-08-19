package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultframework")

-- namespace CosmicVaultArsenal
CosmicVaultArsenal = CosmicVaultArsenal or {}

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

    local turret = InventoryTurret()
    turret.rarity = config.rarity or Rarity(RarityType.Common)
    turret.material = config.material or Material(MaterialType.Iron)
    turret.weaponName = config.weaponType or WeaponType.ChainGun
    turret.coaxial = config.coaxial or false
    turret.size = config.size or 1.0
    turret.slots = config.slots or 1

    local weapon = Weapon(config.weaponType or WeaponType.ChainGun)
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

    local crew = Crew()
    crew:add(math.max(1, math.floor(turret.slots * 1.5)), CrewProfession(CrewProfessionType.Gunner))
    turret.crew = crew

    -- Re-evaluate to lock in stats
    -- turret:updateStaticAttributes() -- Removed: improperly used method

    return turret
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
