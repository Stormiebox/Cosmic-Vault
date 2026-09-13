local CosmicVaultWeatherDictionary = {}

local definitions = {
    IonStorm = {
        type = "IonStorm",
        category = "weather",
        stackingGroup = "atmosphere",
        icon = "data/textures/icons/lightning-field.png",
        color = {r = 0.2, g = 0.5, b = 1.0},
        name = "Ion Storm",
        detailedName = "Severe Ion Storm",
        description = "Radar and hyperspace systems are impaired. Sensors are effectively useless.",
        chatWarning = "WARNING: Ion Storm detected! Radar and hyperspace systems impaired.",
        presentationProfile = "ion",
        mechanicsProfile = "ion",
        hostileToEclipse = false
    },
    SolarFlare = {
        type = "SolarFlare",
        category = "weather",
        stackingGroup = "atmosphere",
        icon = "data/textures/icons/round-star.png",
        color = {r = 1.0, g = 0.5, b = 0.0},
        name = "Solar Flare",
        detailedName = "Violent Solar Flare",
        description = "Intense radiation drains shields and damages exposed hull. Trinium-heavy hulls reduce physical damage.",
        chatWarning = "WARNING: Solar Flare detected! Shields are actively draining.",
        presentationProfile = "solar",
        mechanicsProfile = "solar",
        hostileToEclipse = true
    },
    DarkMatterFog = {
        type = "DarkMatterFog",
        category = "weather",
        stackingGroup = "atmosphere",
        icon = "data/textures/icons/acid-fog.png",
        color = {r = 0.5, g = 0.0, b = 0.5},
        name = "Dark Matter Fog",
        detailedName = "Dense Dark Matter Fog",
        description = "Radar and hyperspace reach are severely impaired by a dark matter anomaly.",
        chatWarning = "WARNING: Dark Matter Fog detected! Radar and hyperspace reach severely impaired.",
        presentationProfile = "fog",
        mechanicsProfile = "dark_fog",
        hostileToEclipse = false
    },
    RiftInstability = {
        type = "RiftInstability",
        category = "rift",
        stackingGroup = "rift",
        icon = "data/textures/icons/hazard-sign.png",
        color = {r = 0.65, g = 0.2, b = 1.0},
        name = "Rift Instability",
        detailedName = "Unstable Rift Distortion",
        description = "Local space is unstable. Violent subspace effects may threaten nearby ships.",
        chatWarning = "WARNING: Rift instability detected! Exercise extreme caution.",
        presentationProfile = "rift",
        mechanicsProfile = "presentation_only",
        hostileToEclipse = false
    }
}

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return copy
end

function CosmicVaultWeatherDictionary.getDefinitions()
    return deepCopy(definitions)
end

function CosmicVaultWeatherDictionary.getDefinition(weatherType)
    if type(weatherType) ~= "string" then return nil end
    return deepCopy(definitions[weatherType])
end

function CosmicVaultWeatherDictionary.getColor(definition)
    local color = definition and definition.color
    if type(color) ~= "table" then return ColorRGB(1, 1, 1) end
    return ColorRGB(tonumber(color.r) or 1, tonumber(color.g) or 1, tonumber(color.b) or 1)
end

function CosmicVaultWeatherDictionary.isEclipse(entity)
    if not entity then return false end
    local faction = Faction(entity.factionIndex)
    if not faction or faction.isPlayer or faction.isAlliance then return false end
    return faction.name == "The Eclipse" or faction:getValue("is_eclipse") == true
end

function CosmicVaultWeatherDictionary.getSolarPreparation(ship)
    local plan = Plan(ship)
    if not plan then return false, 1.0 end

    local safeVolume = 0
    for index = 0, plan.numBlocks - 1 do
        local block = plan:getNthBlock(index)
        if block.material.value >= MaterialType.Trinium then
            local size = block.box.size
            safeVolume = safeVolume + size.x * size.y * size.z
        end
    end

    if safeVolume > plan.volume * 0.5 then return true, 0.5 end
    return false, 1.0
end

-- The data field keeps the old dictionary lookup surface. Persistent records
-- use the serializable definitions above and call mechanics helpers directly.
CosmicVaultWeatherDictionary.data = deepCopy(definitions)
CosmicVaultWeatherDictionary.data.IonStorm.isShipPrepared = function() return true, 1.0 end
CosmicVaultWeatherDictionary.data.SolarFlare.isShipPrepared = CosmicVaultWeatherDictionary.getSolarPreparation
CosmicVaultWeatherDictionary.data.DarkMatterFog.isShipPrepared = function() return true, 1.0 end
CosmicVaultWeatherDictionary.data.RiftInstability.isShipPrepared = function() return true, 1.0 end

for _, definition in pairs(CosmicVaultWeatherDictionary.data) do
    definition.color = CosmicVaultWeatherDictionary.getColor(definition)
end

return CosmicVaultWeatherDictionary
