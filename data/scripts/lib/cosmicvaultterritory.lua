package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")

local CosmicVaultTerritory = {}

-- This API handles background sieges and contested zones for Cosmic War and other expansions.
-- It avoids loading 1,000 sectors to simulate combat, instead mathematically conquering sectors.

if onServer() then

    local function serializeZones(zones)
        local parts = {}
        for key, zone in pairs(zones) do
            table.insert(parts, key .. "=" .. zone.x .. "," .. zone.y .. "," .. tostring(zone.invader) .. "," .. tostring(zone.defender) .. "," .. tostring(zone.endTime) .. "," .. tostring(zone.startTime))
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
                        endTime = tonumber(vals[5]),
                        startTime = tonumber(vals[6]) or (tonumber(vals[5]) - 3600)
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
            endTime = Server().unpausedRuntime + (durationMinutes * 60),
            startTime = Server().unpausedRuntime
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

--- Resolves a siege outcome mathematically, deferring station flipping until player visit
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param newFactionIndex (number) The winning faction index
    function CosmicVaultTerritory.resolveSiege(x, y, newFactionIndex)
    if not x or not y or not newFactionIndex then return end
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y

        if zones[key] then
            zones[key] = nil
            Server():setValue("CosmicVault_ContestedZones", serializeZones(zones))
        end

        -- PROGRESSIVE MATERIALIZATION (Lag Fix)
        -- We no longer call galaxy:loadSector(x, y). Instead we queue the flip for when a player visits.
        local pending = Server():getValue("CosmicVault_PendingFlips") or ""
        local entry = x .. "__" .. y .. "__" .. tostring(newFactionIndex) .. ","
        if not string.find(pending, entry, 1, true) then
            Server():setValue("CosmicVault_PendingFlips", pending .. entry)
        end

        include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Sector " .. x .. ":" .. y .. " mathematically conquered by faction " .. tostring(newFactionIndex))
    end

--- Server update loop for territory control
-- @param timeStep (number) The time step
    function CosmicVaultTerritory.updateServer(timeStep)
        local zones = CosmicVaultTerritory.getContestedZones()
        local currentTime = Server().unpausedRuntime

        for key, zone in pairs(zones) do
            if currentTime >= zone.endTime then
                -- The background siege timer completed! The AI won mathematically.
                CosmicVaultTerritory.resolveSiege(zone.x, zone.y, zone.invader)
            end
        end
    end

--- Expands a faction's territory mathematically, deferring station generation until player visit
-- @param x (number) X coordinate
-- @param y (number) Y coordinate
-- @param factionIndex (number) The faction index expanding (or nil if pirate generation)
-- @param isPirate (boolean) If true, generates a pirate outpost instead
    function CosmicVaultTerritory.expandToSector(x, y, factionIndex, isPirate)
        if not x or not y then return end
        
        -- PROGRESSIVE MATERIALIZATION (Lag Fix)
        local pending = Server():getValue("CosmicVault_PendingExpansions") or ""
        local factionStr = factionIndex and tostring(factionIndex) or "nil"
        local pirateStr = isPirate and "true" or "false"
        local entry = x .. "__" .. y .. "__" .. factionStr .. "__" .. pirateStr .. ","
        
        if not string.find(pending, entry, 1, true) then
            Server():setValue("CosmicVault_PendingExpansions", pending .. entry)
            
            if not isPirate and factionIndex then
                local faction = Faction(factionIndex)
                if faction then
                    include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Faction " .. faction.name .. " scheduled expansion to " .. x .. ":" .. y)
                    local CosmicVaultNews = include("cosmicvaultnews")
                    if CosmicVaultNews and CosmicVaultNews.publishArticle then
                        CosmicVaultNews.publishArticle({
                            title = "Galactic Borders Shift",
                            content = "The " .. faction.name .. " has officially expanded their sovereign territory, claiming the uncharted sector [\\s(" .. x .. ":" .. y .. ")]. New stations are already operational as the faction establishes its presence.",
                            category = "Politics",
                            author = "Cosmic Chronicles"
                        })
                    end
                end
            else
                include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Pirates scheduled expansion to " .. x .. ":" .. y)
            end
        end
    end

end

return CosmicVaultTerritory
