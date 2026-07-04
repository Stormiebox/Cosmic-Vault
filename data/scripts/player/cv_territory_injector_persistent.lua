package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onServer() then
        local pending = Server():getValue("CosmicVault_PendingFlips")
        if pending then
            local key = x .. "_" .. y
            if pending[key] then
                local newFactionIndex = pending[key]
                -- Running in player/sector context, so Sector() is 100% legal here
                local sector = Sector()
                if sector then
                    local stations = {sector:getEntitiesByType(EntityType.Station)}
                    for _, station in pairs(stations) do
                        -- Only flip stations that are owned by AI factions
                        local currentFaction = Faction(station.factionIndex)
                        if currentFaction and currentFaction.isAIFaction then
                            station.factionIndex = newFactionIndex
                        end
                    end
                    include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Executed pending territory flip in " .. x .. ":" .. y .. " to faction " .. tostring(newFactionIndex))
                    
                    -- Remove from pending
                    pending[key] = nil
                    Server():setValue("CosmicVault_PendingFlips", pending)
                end
            end
        end
    end
end
