package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultStation
CosmicVaultStation = {}

--- Registers a completely new dialogue interaction tab natively
-- @param buttonText (string) The text to display on the interact window
-- @param windowTitle (string) The title of the dialogue window when opened
-- @param onInteractionCallback (string) The name of the function to call when clicked
function CosmicVaultStation.injectInteraction(buttonText, windowTitle, onInteractionCallback)
    if not onClient() then return end
    
    -- Avorion automatically scans all scripts on an entity for 'interactionPossible' 
    -- and 'initUI' methods. This helper just standardizes the boilerplate.
    
    -- When the player interacts with the station, add our button
    local oldInitUI = initUI
    initUI = function(...)
        if oldInitUI then oldInitUI(...) end
        ScriptUI():registerInteraction(buttonText, onInteractionCallback)
    end
end

--- Returns true if the player is allowed to interact with the station (Docking range and relations)
-- @return boolean
function CosmicVaultStation.isInteractionPossible()
    if not onClient() then return false end
    
    local player = Player()
    local ship = player.craft
    if not ship then return false end

    local station = Entity()
    if ship.factionIndex == station.factionIndex then return true end
    
    -- Check relation and distance
    if player:getRelations(station.factionIndex) <= -30000 then return false end
    
    local dist = ship:getNearestDistance(station)
    if dist > 50 then return false end
    
    return true
end

return CosmicVaultStation
