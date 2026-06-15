package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local cv_weather_type = "None"
local cv_ui_element = nil

function initialize(weatherType)
    cv_weather_type = weatherType or "None"
    
    if onClient() then
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")
    end
end

function onPreRenderHud()
    if cv_weather_type == "None" then return end
    
    local res = getResolution()
    local x = res.x / 2 - 150
    local y = 80 -- Draw near the top middle
    
    local text = ""
    local color = ColorRGB(1, 0, 0)
    
    if cv_weather_type == "IonStorm" then
        text = "⚠️ ION STORM: Radar & Hyperspace Disabled"
        color = ColorRGB(0.2, 0.5, 1.0)
    elseif cv_weather_type == "SolarFlare" then
        text = "⚠️ SOLAR FLARE: Shields Draining"
        color = ColorRGB(1.0, 0.5, 0.0)
    elseif cv_weather_type == "DarkMatterFog" then
        text = "⚠️ DARK MATTER FOG: Sensors Impaired"
        color = ColorRGB(0.5, 0.0, 0.5)
    end
    
    drawTextRect(text, Rect(x, y, x + 300, y + 30), 0, 0, color, 18, 0, 0, 2)
end
