package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultFactionIndex
CosmicVaultFactionIndex = {}

function CosmicVaultFactionIndex.initialize()
    if onServer() then
        local server = Server()
        if not server:getValue("factions_ready") then
            server:setValue("factions", {})
            server:setValue("factions_last_refresh", 0)
            server:setValue("factions_source", "cosmicvault_faction_indexer_v1")
            server:setValue("factions_ready", false)
        end
    end
end

function CosmicVaultFactionIndex.getUpdateInterval()
    return 300 -- Refresh every 5 minutes
end

function CosmicVaultFactionIndex.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local indices = {}
    local uniqueIndices = {}
    local finalIndices = {}

    -- Collect player and alliance factions
    for _, player in pairs({ server:getPlayers() }) do
        table.insert(indices, player.index)
        if player.allianceIndex then
            table.insert(indices, player.allianceIndex)
        end
    end

    -- Collect AI Factions (Avorion typically indexes AI factions in the 1 to 2000 range)
    for i = 1, 2500 do
        local f = Faction(i)
        if f then
            table.insert(indices, f.index)
        end
    end

    for _, idx in ipairs(indices) do
        if not uniqueIndices[idx] then
            uniqueIndices[idx] = true
            table.insert(finalIndices, idx)
        end
    end

    server:setValue("factions", finalIndices)
    server:setValue("factions_last_refresh", server.unpausedRuntime or 0)
    server:setValue("factions_source", "cosmicvault_faction_indexer_v1")
    server:setValue("factions_ready", true)
    server:setValue("factions_count", #finalIndices)
end
