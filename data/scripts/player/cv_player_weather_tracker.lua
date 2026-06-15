package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local cv_active_weathers = {}

function initialize()
    Player():registerCallback("onSectorEntered", "onSectorEntered")
end

function syncWeatherMap(weatherMap)
    cv_active_weathers = weatherMap or {}
    forceSectorCheck()
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    forceSectorCheck()
end

function forceSectorCheck()
    if onClient() then return end
    
    local player = Player()
    local x, y = player:getSectorCoordinates()
    local key = tostring(x) .. "_" .. tostring(y)
    
    local weather = cv_active_weathers[key]
    if weather then
        local sector = Sector()
        if sector and not sector:hasScript("sector/cv_weather_controller.lua") then
            -- Calculate remaining duration
            local remaining = weather.expiry - os.time()
            if weather.expiry == -1 then
                remaining = -1
            end
            
            if remaining > 0 or remaining == -1 then
                sector:addScriptOnce("data/scripts/sector/cv_weather_controller.lua", weather.type, remaining)
            end
        end
    end
end

function forceSectorCleanup()
    if onClient() then return end
    local sector = Sector()
    if sector and sector:hasScript("sector/cv_weather_controller.lua") then
        sector:removeScript("sector/cv_weather_controller.lua")
    end
end
