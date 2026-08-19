package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultdebug")
include("randomext")

-- namespace CosmicVaultDialogue
CosmicVaultDialogue = {}
CosmicVaultDialogue._registeredLines = {}

-- Registers a single line entry from any mod
function CosmicVaultDialogue.registerLine(entry)
    if not entry or not entry.category or not entry.text then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("CosmicVaultDialogue", "Invalid entry provided. Must contain 'category' and 'text'.")
        else
            include("cosmicvaultdebug").info("Cosmic Vault", "CosmicVaultDialogue [Error]: Invalid entry provided. Must contain 'category' and 'text'.")
        end
        return
    end

    -- Initialize category if it doesn't exist
    if not CosmicVaultDialogue._registeredLines[entry.category] then
        CosmicVaultDialogue._registeredLines[entry.category] = {}
    end

    table.insert(CosmicVaultDialogue._registeredLines[entry.category], entry)
end

-- Retrieves a random valid string based on category and contextual conditions
function CosmicVaultDialogue.getValidLine(category, currentContext)
    local lines = CosmicVaultDialogue._registeredLines[category]
    if not lines or #lines == 0 then return nil end

    local validLines = {}
    currentContext = currentContext or {}

    for _, entry in pairs(lines) do
        local isValid = true

        -- Validate conditions if they exist
        if entry.conditions then
            if entry.conditions.minWarHeat and (currentContext.warHeat or 0) < entry.conditions.minWarHeat then
                isValid = false
            end
            if isValid and entry.conditions.maxWarHeat and (currentContext.warHeat or 0) > entry.conditions.maxWarHeat then
                isValid = false
            end
            if isValid and entry.conditions.factionTrait and currentContext.factionTrait ~= entry.conditions.factionTrait then
                isValid = false
            end
            if isValid and entry.conditions.factionWealth and currentContext.factionWealth ~= entry.conditions.factionWealth then
                isValid = false
            end
            if isValid and entry.conditions.stationType and currentContext.stationType ~= entry.conditions.stationType then
                isValid = false
            end
            if isValid and entry.conditions.minDistanceToCenter and (currentContext.distanceToCenter or 0) < entry.conditions.minDistanceToCenter then
                isValid = false
            end
            if isValid and entry.conditions.maxDistanceToCenter and (currentContext.distanceToCenter or 500) > entry.conditions.maxDistanceToCenter then
                isValid = false
            end
            if isValid and entry.conditions.minReputation and (currentContext.reputation or 0) < entry.conditions.minReputation then
                isValid = false
            end
            if isValid and entry.conditions.maxReputation and (currentContext.reputation or 0) > entry.conditions.maxReputation then
                isValid = false
            end
        end

        if isValid then
            table.insert(validLines, entry.text)
        end
    end

    if #validLines == 0 then return nil end

    -- Use Avorion's global random() object to pick a valid line safely
    return validLines[random():getInt(1, #validLines)]
end

return CosmicVaultDialogue