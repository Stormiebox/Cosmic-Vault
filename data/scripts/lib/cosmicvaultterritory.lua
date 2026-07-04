package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")

local CosmicVaultTerritory = {}

-- This API handles background sieges and contested zones for Cosmic War and other expansions.
-- It avoids loading 1,000 sectors to simulate combat, instead mathematically conquering sectors.

if onServer() then

    local function serializeZones(zones)
        local parts = {}
        for key, zone in pairs(zones) do
            table.insert(parts, key .. "=" .. zone.x .. "," .. zone.y .. "," .. tostring(zone.invader) .. "," .. tostring(zone.defender) .. "," .. tostring(zone.endTime))
        end
        return table.concat(parts, ";")
    end

    local function deserializeZones(str)
        local zones = {}
        if type(str) ~= "string" or str == "" then return zones end
        local fragments = str:split(";")
        for _, part in ipairs(fragments) do
            local kv = part:split("=")
            if #kv == 2 then
                local key = kv[1]
                local vals = kv[2]:split(",")
                if #vals >= 5 then
                    zones[key] = {
                        x = tonumber(vals[1]),
                        y = tonumber(vals[2]),
                        invader = tonumber(vals[3]) or vals[3],
                        defender = tonumber(vals[4]) or vals[4],
                        endTime = tonumber(vals[5])
                    }
                end
            end
        end
        return zones
    end

--- Gets all active contested zones
-- @return (table) Contested zones list
    function CosmicVaultTerritory.getContestedZones()
        local server = Server()
        local zonesStr = server:getValue("CosmicVault_ContestedZones")
        local zones = deserializeZones(zonesStr)
        return zones
    end

--- Sets the contested state of a zone
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param state (boolean) Contested state
-- @param attackers (table) Attacking faction info
    function CosmicVaultTerritory.setContestedZone(x, y, invadingFactionIndex, defendingFactionIndex, durationMinutes)
    if not x or not y then return end
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y

        zones[key] = {
            x = x,
            y = y,
            invader = invadingFactionIndex,
            defender = defendingFactionIndex,
            endTime = Server().unpausedRuntime + (durationMinutes * 60)
        }

        Server():setValue("CosmicVault_ContestedZones", serializeZones(zones))
        include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Sector " .. x .. ":" .. y .. " is now Contested!")
    end

--- Removes a contested zone from the tracking table without resolving a victor
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
    function CosmicVaultTerritory.removeContestedZone(x, y)
        if not x or not y then return end
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y

        if zones[key] then
            zones[key] = nil
            Server():setValue("CosmicVault_ContestedZones", serializeZones(zones))
        end
    end

--- Resolves a siege outcome
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param winner (string) The winning faction name
    function CosmicVaultTerritory.resolveSiege(x, y, newFactionIndex)
    if not x or not y or not newFactionIndex then return end
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y

        if zones[key] then
            zones[key] = nil
            Server():setValue("CosmicVault_ContestedZones", serializeZones(zones))
        end

        -- Briefly load the sector to flip the stations, permanently changing the Galaxy Map borders.
        -- This uses the engine's native influence calculation safely.
        local galaxy = Galaxy()
        galaxy:loadSector(x, y)

        for _, player in pairs({Server():getOnlinePlayers()}) do
            local px, py = player:getSectorCoordinates()
            if px == x and py == y then
                player:invokeFunction("cw_battlefieldhud.lua", "triggerSiegeSuccess")
            end
        end

        -- To actually flip the stations, we must run a small script inside the sector once it loads.
        -- We will invoke a background task to flip it.
        galaxy:invokeFunction("data/scripts/galaxy/server.lua", "flipSectorTerritory", x, y, newFactionIndex)
        include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Sector " .. x .. ":" .. y .. " conquered by faction " .. tostring(newFactionIndex))
    end

--- Server update loop for territory control
-- @param timeStep (number) The time step
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
            Server():setValue("CosmicVault_ContestedZones", serializeZones(zones))
        end
    end

--- Expands a faction's territory into an uncharted or empty sector natively
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param factionIndex (number) The faction index expanding (or nil if pirate generation)
-- @param isPirate (boolean) If true, generates a pirate outpost instead
    function CosmicVaultTerritory.expandToSector(x, y, factionIndex, isPirate)
        if not x or not y then return end
        local galaxy = Galaxy()
        local sector = galaxy:loadSector(x, y)
        if not sector then return end

        local faction
        if factionIndex then
            faction = Faction(factionIndex)
        end

        if isPirate then
            local PirateGenerator = include("pirategenerator")
            local level = Balancing_GetPirateLevel(x, y)
            faction = galaxy:getPirateFaction(level)

            if not faction then
                -- galaxy:tryUnloadSector(x, y) -- Removed: Unloading is handled by the engine
                return
            end

            local SectorGenerator = include("sectorgenerator")
            local generator = SectorGenerator(x, y)

            local random = random()
            local station
            if random:getFloat() < 0.5 then
                station = generator:createStation(faction, "data/scripts/entity/merchants/smugglersmarket.lua")
                station.title = "Smuggler's Hideout"
            else
                station = generator:createStation(faction, "data/scripts/entity/merchants/shipyard.lua")
                station.title = "Pirate Shipyard"
            end

            include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Pirates expanded to " .. x .. ":" .. y)
            -- galaxy:tryUnloadSector(x, y) -- Removed: Unloading is handled by the engine
        else
            if not faction then
                -- galaxy:tryUnloadSector(x, y) -- Removed: Unloading is handled by the engine
                return
            end

            local SectorGenerator = include("sectorgenerator")
            local generator = SectorGenerator(x, y)

            local types = {
                "data/scripts/entity/merchants/militaryoutpost.lua",
                "data/scripts/entity/merchants/resourcedepot.lua",
                "data/scripts/entity/merchants/tradingpost.lua",
                "data/scripts/entity/merchants/researchstation.lua"
            }
            local script = types[random():getInt(1, #types)]

            generator:createStation(faction, script)

            include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Faction " .. faction.name .. " expanded to " .. x .. ":" .. y)

            local CosmicVaultNews = include("cosmicvaultnews")
            if CosmicVaultNews and CosmicVaultNews.publishArticle then
                CosmicVaultNews.publishArticle({
                    title = "Galactic Borders Shift",
                    content = "The " .. faction.name .. " has officially expanded their sovereign territory, claiming the uncharted sector [\\s(" .. x .. ":" .. y .. ")]. New stations are already operational as the faction establishes its presence.",
                    category = "Politics",
                    author = "Cosmic Chronicles"
                })
            end

            -- galaxy:tryUnloadSector(x, y) -- Removed: Unloading is handled by the engine
        end
    end

end

return CosmicVaultTerritory
