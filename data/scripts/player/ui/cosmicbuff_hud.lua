
local activeBuffs = {}

function initialize()
    if onClient() then
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")
    end
end

-- Invoked natively via local client-to-client invokeFunction from entity scripts
function registerBuff(buffId, targetStat, timeRemaining, maxDuration)
    if not onClient() then return end
    if timeRemaining <= 0 then return end
    
    activeBuffs[buffId] = {
        stat = targetStat,
        time = timeRemaining,
        max = maxDuration,
        lastUpdate = appTime()
    }
end

function onPreRenderHud()
    if not onClient() then return end
    
    local currentTime = appTime()
    local yOffset = 150
    local screen = vec2(getResolution())
    local xPos = screen.x - 220
    
    for id, data in pairs(activeBuffs) do
        -- Interpolate locally so we don't need network syncs every frame
        local timeSinceUpdate = currentTime - data.lastUpdate
        local remaining = data.time - timeSinceUpdate
        
        if remaining > 0 then
            -- Progress Calculation
            local percentage = math.max(0, math.min(1, remaining / data.max))
            
            -- Background
            local bgRect = Rect(xPos, yOffset, xPos + 200, yOffset + 20)
            drawRect(bgRect, ColorARGB(0.6, 0.05, 0.05, 0.1))
            
            -- Foreground (Progress)
            local fgRect = Rect(xPos, yOffset, xPos + (200 * percentage), yOffset + 20)
            -- A sleek teal/blue color to match the "Cosmic" UI aesthetics
            drawRect(fgRect, ColorARGB(0.8, 0.1, 0.8, 1.0)) 
            
            -- Text
            local text = data.stat .. ": " .. string.format("%.0fs", remaining)
            -- Format it cleanly in the center of the bar
            drawText(text, xPos + 10, yOffset + 2, ColorRGB(1, 1, 1), 12, 0, 0, 2)
            
            yOffset = yOffset + 30
        else
            -- Cleanup expired buffs locally
            activeBuffs[id] = nil
        end
    end
end
