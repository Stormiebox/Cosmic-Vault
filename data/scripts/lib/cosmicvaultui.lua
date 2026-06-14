package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultframework")

-- namespace CosmicVaultUI
CosmicVaultUI = CosmicVaultUI or {}

--[[
    Cosmic Vault UI API
    Allows modders to trigger cinematic overlays and unified UI elements dynamically.
    Requires the player to have "data/scripts/player/cosmicvaultcinematic.lua" attached.
]]

--- Shows a cinematic banner to a player
-- @param player (Player) The player
-- @param title (string) The banner title
-- @param subtitle (string) The subtitle
-- @param color (Color) Text color
function CosmicVaultUI.ShowCinematicBanner(player, text, color, soundPath, duration)
    if not valid(player) then return false end
    if not player:hasScript("cosmicvaultcinematic.lua") then
        player:addScriptOnce("cosmicvaultcinematic.lua")
    end

    local cInfo = {
        r = color.r or 1.0,
        g = color.g or 1.0,
        b = color.b or 1.0
    }
    
    player:invokeFunction("cosmicvaultcinematic.lua", "showBanner", text, cInfo, soundPath, duration)
    return true
end

--- Shows a popup dialogue to a player
-- @param player (Player) The player
-- @param text (string) The popup text
-- @param title (string) The popup title
function CosmicVaultUI.ShowPopup(player, title, message)
    if not valid(player) then return false end
    if not player:hasScript("cosmicvaultcinematic.lua") then
        player:addScriptOnce("cosmicvaultcinematic.lua")
    end

    player:invokeFunction("cosmicvaultcinematic.lua", "showPopup", title, message)
    return true
end
--- Displays floating text at an entity's location
-- @param entity (Entity) The target entity
-- @param text (string) The text to display
-- @param color (Color) The text color
function CosmicVaultUI.displayFloatingText(player, entityId, text, color)
    if not valid(player) then return false end
    if not player:hasScript("cosmicvaultcinematic.lua") then
        player:addScriptOnce("cosmicvaultcinematic.lua")
    end
    
    local cInfo = {
        r = color.r or 1.0,
        g = color.g or 1.0,
        b = color.b or 1.0
    }

    player:invokeFunction("cosmicvaultcinematic.lua", "showFloatingText", entityId, text, cInfo)
    return true
end

if CosmicVaultFramework and CosmicVaultFramework.registerModule then
    CosmicVaultFramework.registerModule("CosmicVaultUI", {version = "1.0.0"})
end

return CosmicVaultUI
