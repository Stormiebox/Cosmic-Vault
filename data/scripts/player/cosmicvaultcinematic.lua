package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultCinematic
CosmicVaultCinematic = {}

--[[
    Client-side renderer for the CosmicVaultUI API.
    Handles animations, sounds, and overlays without interrupting the player.
]]

local bannerActive = false
local bannerText = ""
local bannerColor = ColorRGB(1, 1, 1)
local bannerTimer = 0
local bannerDuration = 5

function CosmicVaultCinematic.initialize()
    if onServer() then return end
    Player():registerCallback("onPreRenderHud", "onPreRenderHud")
end

function CosmicVaultCinematic.showBanner(text, cInfo, soundPath, duration)
    if onServer() then
        invokeClientFunction(Player(), "showBanner", text, cInfo, soundPath, duration)
        return
    end

    bannerText = text
    bannerColor = ColorRGB(cInfo.r, cInfo.g, cInfo.b)
    bannerDuration = duration or 5
    bannerTimer = bannerDuration
    bannerActive = true

    if soundPath and soundPath ~= "" then
        playSound(soundPath, 0, 1.0, false)
    end
end

function CosmicVaultCinematic.showPopup(title, message)
    if onServer() then
        invokeClientFunction(Player(), "showPopup", title, message)
        return
    end

    -- Using vanilla UI popup
    displayChatMessage(message, title, 0)
end

function CosmicVaultCinematic.showFloatingText(entityId, text, cInfo)
    if onServer() then
        invokeClientFunction(Player(), "showFloatingText", entityId, text, cInfo)
        return
    end
    -- Fallback to combat log since Avorion lacks 3D text renderer from Lua
    local color = ColorRGB(cInfo.r, cInfo.g, cInfo.b)

    local entity = Entity(entityId)
    local name = entity and entity.translatedTitle or "Unknown Entity"

    -- We can use a message type 3 for floating text style output in the middle of screen
    displayChatMessage(string.format("[%s] %s", name, text), "", 3)
end

function CosmicVaultCinematic.updateClient(timeStep)
    if bannerActive then
        bannerTimer = bannerTimer - timeStep
        if bannerTimer <= 0 then
            bannerActive = false
        end
    end
end

function CosmicVaultCinematic.onPreRenderHud()
    if not bannerActive then return end

    local resolution = getResolution()
    local alpha = 1.0

    -- Fade in / fade out logic
    if bannerDuration - bannerTimer < 0.5 then
        alpha = (bannerDuration - bannerTimer) * 2
    elseif bannerTimer < 0.5 then
        alpha = bannerTimer * 2
    end

    local rect = Rect(0, resolution.y * 0.2, resolution.x, resolution.y * 0.3)

    -- Draw background
    local bgColor = ColorARGB(alpha * 0.8, 0, 0, 0)
    drawRect(rect, bgColor)

    -- Draw text
    local textColor = ColorARGB(alpha, bannerColor.r, bannerColor.g, bannerColor.b)
    drawTextRect(bannerText, rect, 1, textColor, 40, 1, 1, 2)
end


function initialize(...)
    if CosmicVaultCinematic.initialize then return CosmicVaultCinematic.initialize(...) end
end
function updateClient(...)
    if CosmicVaultCinematic.updateClient then return CosmicVaultCinematic.updateClient(...) end
end


-- Global Event Callbacks
function onPreRenderHud(...)
    if CosmicVaultCinematic.onPreRenderHud then return CosmicVaultCinematic.onPreRenderHud(...) end
end

return CosmicVaultCinematic
