-- Shared upgrade-system category registry. Lets any Cosmic mod sort a system upgrade script
-- (e.g. "data/scripts/systems/shieldbooster.lua") into Military/Civilian/Misc for category-based
-- shop UIs (see Cosmic Overhaul's split Equipment Dock tabs) without hand-maintaining a private
-- lookup table per mod. Vanilla has no native category for upgrade *systems* the way it does for
-- turrets (StatsBonuses.armedTypes/unarmedTypes/defensiveTypes) -- this is the Cosmic Vault
-- equivalent, built so a new upgrade system stays correctly sorted by having its own mod register
-- it here, instead of every consumer's category table silently going stale as new systems ship.

local CosmicVaultUpgradeCategories = {}

CosmicVaultUpgradeCategories.Category = {
    Military = 1,
    Civilian = 2,
    Misc = 3,
}

local categories = {}

local function isValidCategory(category)
    return category == CosmicVaultUpgradeCategories.Category.Military
        or category == CosmicVaultUpgradeCategories.Category.Civilian
        or category == CosmicVaultUpgradeCategories.Category.Misc
end

local function register(scriptPath, category)
    categories[scriptPath] = category
end

-- Vanilla defaults. Cross-referenced directly against the "scripts" table registered in vanilla's
-- own data/scripts/lib/upgradegenerator.lua (the actual list of what a shop can generate) rather
-- than the systems/ folder listing, which also contains quest-locked items (teleporterkey1-8.lua,
-- wormholeopener.lua), Behemoth-exclusive systems (behemoth*.lua), and an internal base class
-- (basesystem.lua) that a normal shop never generates. All 25 currently-registered vanilla scripts
-- are covered below.

-- Military: combat turret control, shield combat systems, defensive/offensive combat utility.
register("data/scripts/systems/militarytcs.lua", CosmicVaultUpgradeCategories.Category.Military)
register("data/scripts/systems/arbitrarytcs.lua", CosmicVaultUpgradeCategories.Category.Military)
register("data/scripts/systems/autotcs.lua", CosmicVaultUpgradeCategories.Category.Military)
register("data/scripts/systems/shieldbooster.lua", CosmicVaultUpgradeCategories.Category.Military)
register("data/scripts/systems/shieldimpenetrator.lua", CosmicVaultUpgradeCategories.Category.Military)
register("data/scripts/systems/energytoshieldconverter.lua", CosmicVaultUpgradeCategories.Category.Military)
register("data/scripts/systems/weaknesssystem.lua", CosmicVaultUpgradeCategories.Category.Military)
register("data/scripts/systems/resistancesystem.lua", CosmicVaultUpgradeCategories.Category.Military)
register("data/scripts/systems/defensesystem.lua", CosmicVaultUpgradeCategories.Category.Military)

-- Civilian: economy, mining, trading, and non-combat turret control.
register("data/scripts/systems/civiltcs.lua", CosmicVaultUpgradeCategories.Category.Civilian)
register("data/scripts/systems/cargoextension.lua", CosmicVaultUpgradeCategories.Category.Civilian)
register("data/scripts/systems/energybooster.lua", CosmicVaultUpgradeCategories.Category.Civilian)
register("data/scripts/systems/enginebooster.lua", CosmicVaultUpgradeCategories.Category.Civilian)
register("data/scripts/systems/lootrangebooster.lua", CosmicVaultUpgradeCategories.Category.Civilian)
register("data/scripts/systems/miningsystem.lua", CosmicVaultUpgradeCategories.Category.Civilian)
register("data/scripts/systems/tradingoverview.lua", CosmicVaultUpgradeCategories.Category.Civilian)
register("data/scripts/systems/valuablesdetector.lua", CosmicVaultUpgradeCategories.Category.Civilian)

-- Misc: general-purpose ship stat boosters that aren't specifically combat or economy focused.
register("data/scripts/systems/fightersquadsystem.lua", CosmicVaultUpgradeCategories.Category.Misc)
register("data/scripts/systems/batterybooster.lua", CosmicVaultUpgradeCategories.Category.Misc)
register("data/scripts/systems/hyperspacebooster.lua", CosmicVaultUpgradeCategories.Category.Misc)
register("data/scripts/systems/transportersoftware.lua", CosmicVaultUpgradeCategories.Category.Misc)
register("data/scripts/systems/velocitybypass.lua", CosmicVaultUpgradeCategories.Category.Misc)
register("data/scripts/systems/excessvolumebooster.lua", CosmicVaultUpgradeCategories.Category.Misc)
register("data/scripts/systems/radarbooster.lua", CosmicVaultUpgradeCategories.Category.Misc)
register("data/scripts/systems/scannerbooster.lua", CosmicVaultUpgradeCategories.Category.Misc)

--- Registers (or re-registers) an upgrade system's shop category. Any mod adding a new upgrade
--- system should call this once for each of its own scripts so category-based shop UIs sort it
--- correctly instead of silently defaulting to Misc.
--- @param scriptPath (string) e.g. "data/scripts/systems/bastionSystem.lua"
--- @param category (CosmicVaultUpgradeCategories.Category) Military, Civilian, or Misc
function CosmicVaultUpgradeCategories.registerCategory(scriptPath, category)
    if type(scriptPath) ~= "string" or scriptPath == "" then return end
    if not isValidCategory(category) then return end
    register(scriptPath, category)
end

--- @param scriptPath (string)
--- @return (CosmicVaultUpgradeCategories.Category) Misc if the script was never registered --
--- a safe fallback so an unrecognized upgrade (a not-yet-updated mod, an external Workshop mod's
--- own custom system) still shows up somewhere instead of being silently dropped from every tab.
function CosmicVaultUpgradeCategories.getCategory(scriptPath)
    return categories[scriptPath] or CosmicVaultUpgradeCategories.Category.Misc
end

--- @param category (CosmicVaultUpgradeCategories.Category)
--- @return (table) array of every currently-registered script path in that category
function CosmicVaultUpgradeCategories.getScriptsOfCategory(category)
    local result = {}
    if not isValidCategory(category) then return result end
    for scriptPath, cat in pairs(categories) do
        if cat == category then
            table.insert(result, scriptPath)
        end
    end
    return result
end

return CosmicVaultUpgradeCategories
