package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicVaultTerritory = {}

-- This API handles background sieges and contested zones for Cosmic War and other expansions.
-- It avoids loading 1,000 sectors to simulate combat, instead mathematically conquering sectors.

if onServer() then

    function CosmicVaultTerritory.getContestedZones()
        local server = Server()
        local zones = server:getValue("CosmicVault_ContestedZones")
        if not zones then
            zones = {}
            server:setValue("CosmicVault_ContestedZones", zones)
        end
        return zones
    end

    function CosmicVaultTerritory.setContestedZone(x, y, invadingFactionIndex, defendingFactionIndex, durationMinutes)
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y
        
        zones[key] = {
            x = x,
            y = y,
            invader = invadingFactionIndex,
            defender = defendingFactionIndex,
            endTime = Server().unpausedRuntime + (durationMinutes * 60)
        }
        
        Server():setValue("CosmicVault_ContestedZones", zones)
        print("[Cosmic Vault] Sector " .. x .. ":" .. y .. " is now Contested!")
    end

    function CosmicVaultTerritory.resolveSiege(x, y, newFactionIndex)
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y
        
        if zones[key] then
            zones[key] = nil
            Server():setValue("CosmicVault_ContestedZones", zones)
        end

        -- Briefly load the sector to flip the stations, permanently changing the Galaxy Map borders.
        -- This uses the engine's native influence calculation safely.
        local galaxy = Galaxy()
        galaxy:loadSector(x, y)
        
        -- To actually flip the stations, we must run a small script inside the sector once it loads.
        -- We will invoke a background task to flip it.
        galaxy:invokeFunction("data/scripts/galaxy/server.lua", "flipSectorTerritory", x, y, newFactionIndex)
        print("[Cosmic Vault] Sector " .. x .. ":" .. y .. " conquered by faction " .. tostring(newFactionIndex))
    end

    function CosmicVaultTerritory.updateServer(timeStep)
        local zones = CosmicVaultTerritory.getContestedZones()
        local currentTime = Server().unpausedRuntime
        local changed = false

        for key, zone in pairs(zones) do
            if currentTime >= zone.endTime then
                -- The background siege timer completed! The AI won mathematically.
                CosmicVaultTerritory.resolveSiege(zone.x, zone.y, zone.invader)
                changed = true
            end
        end
        
        if changed then
            -- Note: Server():setValue is automatically saved, but calling it forces a sync if necessary.
            Server():setValue("CosmicVault_ContestedZones", zones)
        end
    end

end

return CosmicVaultTerritory
