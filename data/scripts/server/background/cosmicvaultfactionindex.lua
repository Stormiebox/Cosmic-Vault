package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultFactionIndex
CosmicVaultFactionIndex = {}

function CosmicVaultFactionIndex.initialize()
    if onServer() then
        local server = Server()
        if not server:getValue("factions_ready") then
            server:setValue("factions", "")
            server:setValue("factions_last_refresh", 0)
            server:setValue("factions_source", "cosmicvault_faction_indexer_v1")
            server:setValue("factions_ready", false)
        end
    end
end

function CosmicVaultFactionIndex.getUpdateInterval()
    local server = Server()
    if server and not server:getValue("factions_ready") then
        return 15 -- Short 15-second warm-up delay on first boot
    end
    return 300    -- Refresh every 5 minutes thereafter
end

function CosmicVaultFactionIndex.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local indices = {}
    local uniqueIndices = {}
    local finalIndices = {}

    -- Preserve already discovered high-index factions (Pirates, Xsotan, DLC factions) from the current string
    local currentFactions = server:getValue("factions")
    if type(currentFactions) == "string" and currentFactions ~= "" then
        for id in string.gmatch(currentFactions, "([^,]+)") do
            local numId = tonumber(id)
            if numId and not Player(numId) and not Alliance(numId) then
                table.insert(indices, numId)
            end
        end
    end

    -- Collect AI Factions (Avorion typically indexes AI factions in the 1 to 2000 range)
    for i = 1, 2500 do
        if not Player(i) and not Alliance(i) then
            local f = Faction(i)
            if f then
                table.insert(indices, f.index)
            end
        end
    end

    for _, idx in ipairs(indices) do
        if not uniqueIndices[idx] then
            -- Verify faction actually still exists
            if not Player(idx) and not Alliance(idx) and Faction(idx) then
                uniqueIndices[idx] = true
                table.insert(finalIndices, idx)
            end
        end
    end

    if #finalIndices > 0 then
        server:setValue("factions", table.concat(finalIndices, ","))
    else
        server:setValue("factions", "")
    end
    server:setValue("factions_last_refresh", server.unpausedRuntime or 0)
    server:setValue("factions_source", "cosmicvault_faction_indexer_v1")
    server:setValue("factions_ready", true)
    server:setValue("factions_count", #finalIndices)
end
