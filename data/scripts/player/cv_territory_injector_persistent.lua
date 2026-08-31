
function initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onServer() then
        local pending = Server():getValue("CosmicVault_PendingFlips")
        if type(pending) == "string" and pending ~= "" then
            local searchPattern = tostring(x) .. "__" .. tostring(y) .. "__"
            local startIdx, endIdx = string.find(pending, searchPattern, 1, true)
            if startIdx then
                -- Extract the faction index
                local factionPart = string.sub(pending, endIdx + 1)
                local commaIdx = string.find(factionPart, ",", 1, true)
                if commaIdx then
                    local factionIdxStr = string.sub(factionPart, 1, commaIdx - 1)
                    local newFactionIndex = tonumber(factionIdxStr)
                    
                    -- Running in player/sector context, so Sector() is 100% legal here
                    local sector = Sector()
                    if sector and newFactionIndex then
                        local stations = {sector:getEntitiesByType(EntityType.Station)}
                        for _, station in pairs(stations) do
                            -- Only flip stations that are owned by AI factions
                            local currentFaction = Faction(station.factionIndex)
                            if currentFaction and currentFaction.isAIFaction then
                                station.factionIndex = newFactionIndex
                            end
                        end
                        include("cosmicvaultdebug").info("Cosmic Vault", "[Cosmic Vault] Executed pending territory flip in " .. x .. ":" .. y .. " to faction " .. tostring(newFactionIndex))
                        
                        -- Remove from pending string using exact indices (avoids gsub regex bugs with negative coordinates)
                        local endOfEntry = endIdx + commaIdx
                        local newPending = string.sub(pending, 1, startIdx - 1) .. string.sub(pending, endOfEntry + 1)
                        Server():setValue("CosmicVault_PendingFlips", newPending)
                    end
                end
            end
        end
    end
end
