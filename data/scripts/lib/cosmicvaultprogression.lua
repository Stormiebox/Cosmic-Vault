
-- namespace CosmicVaultProgression
CosmicVaultProgression = {}

local VAULT_PREFIX = "cosmic_progression_"

--- Safely adds Custom XP to a player
-- @param playerIndex (int) The player's index
-- @param xpAmount (int) Amount of XP to add
-- @param skillTreeName (string) The category of XP (e.g. "combat", "mining")
function CosmicVaultProgression.addXP(playerIndex, xpAmount, skillTreeName)
    if not playerIndex or type(xpAmount) ~= "number" or type(skillTreeName) ~= "string" then return end
    if not onServer() then return end
    local player = Player(playerIndex)
    if not player then return end

    local key = VAULT_PREFIX .. skillTreeName .. "_xp"
    local currentXP = player:getValue(key) or 0
    player:setValue(key, currentXP + xpAmount)
end

--- Retrieves current XP for a skill tree
-- @param playerIndex (int) The player's index
-- @param skillTreeName (string) The category of XP
-- @return int Current XP
function CosmicVaultProgression.getXP(playerIndex, skillTreeName)
    if not playerIndex or type(skillTreeName) ~= "string" then return 0 end
    -- Player():getValue() is server-only; calling it on the client crashes.
    if not onServer() then return 0 end
    local player = Player(playerIndex)
    if not player then return 0 end
    
    local key = VAULT_PREFIX .. skillTreeName .. "_xp"
    return player:getValue(key) or 0
end

--- Unlocks a specific perk or ability flag for the player
-- @param playerIndex (int) The player's index
-- @param perkId (string) Unique ID of the perk (e.g. "starfall_shield_boost")
function CosmicVaultProgression.unlockPerk(playerIndex, perkId)
    if not playerIndex or type(perkId) ~= "string" then return end
    if not onServer() then return end
    local player = Player(playerIndex)
    if not player then return end
    
    local key = VAULT_PREFIX .. "perk_" .. perkId
    player:setValue(key, true)
end

--- Checks if a player has a perk unlocked
-- @param playerIndex (int) The player's index
-- @param perkId (string) Unique ID of the perk
-- @return boolean True if unlocked
function CosmicVaultProgression.hasPerk(playerIndex, perkId)
    if not playerIndex or type(perkId) ~= "string" then return false end
    if not onServer() then return false end
    local player = Player(playerIndex)
    if not player then return false end
    
    local key = VAULT_PREFIX .. "perk_" .. perkId
    return player:getValue(key) == true
end

return CosmicVaultProgression
