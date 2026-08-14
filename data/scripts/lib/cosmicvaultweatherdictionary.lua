package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local CosmicVaultWeatherDictionary = {}

CosmicVaultWeatherDictionary.data = {
    ["IonStorm"] = {
        icon = "data/textures/icons/lightning-field.png",
        color = ColorRGB(0.2, 0.5, 1.0),
        name = "Ion Storm",
        detailedName = "Severe Ion Storm",
        description = "Radar and hyperspace systems are impaired. Sensors are effectively useless.",
        chatWarning = "WARNING: Ion Storm detected! Radar and hyperspace systems impaired.",
        isShipPrepared = function(ship)
            -- Ion storm is just a sensor debuff, no specific hull damage reduction needed yet.
            return true, 1.0
        end
    },
    ["SolarFlare"] = {
        icon = "data/textures/icons/round-star.png",
        color = ColorRGB(1.0, 0.5, 0.0),
        name = "Solar Flare",
        detailedName = "Violent Solar Flare",
        description = "Intense radiation is actively draining your shields and damaging exposed hull.",
        chatWarning = "WARNING: Solar Flare detected! Shields are actively draining.",
        isShipPrepared = function(ship)
            -- If a ship's highest material is Trinium (4) or above, it resists 50% of the physical hull damage
            local plan = Plan(ship)
            if not plan then return false, 1.0 end
            
            -- Avorion materials: Iron = 0, Titanium = 1, Naonite = 2, Trinium = 3, Xanion = 4, Ogonite = 5, Avorion = 6.
            local safeMaterialValue = 3 
            
            local numBlocks = plan.numBlocks
            local volumeSafeBlocks = 0
            for i = 0, numBlocks - 1 do
                local block = plan:getNthBlock(i)
                if block.material.value >= safeMaterialValue then
                    volumeSafeBlocks = volumeSafeBlocks + block.volume
                end
            end
            
            -- If more than 50% of the ship's volume is Trinium or above, grant 50% damage reduction
            if volumeSafeBlocks > (plan.volume * 0.5) then
                return true, 0.5
            end
            
            return false, 1.0
        end
    },
    ["DarkMatterFog"] = {
        icon = "data/textures/icons/acid-fog.png",
        color = ColorRGB(0.5, 0.0, 0.5),
        name = "Dark Matter Fog",
        detailedName = "Dense Dark Matter Fog",
        description = "Sensors are severely impaired by a dark matter anomaly.",
        chatWarning = "WARNING: Dark Matter Fog detected! Sensors severely impaired.",
        isShipPrepared = function(ship)
            return true, 1.0
        end
    }
}

return CosmicVaultWeatherDictionary
