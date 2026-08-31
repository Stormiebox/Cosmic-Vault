
local cv_active_weathers = {}

function initialize()
    Player():registerCallback("onSectorEntered", "onSectorEntered")
end

function syncWeatherMap(weatherMap)
    if weatherMap ~= nil and type(weatherMap) ~= "table" then return end
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
    if type(weather) == "table" and weather.type then
        local sector = Sector()
        if sector then
            local scriptPath = "data/scripts/sector/cv_weather_controller.lua"
            local hasWeather = sector:hasScript(scriptPath)
            local overwrite = false
            
            if hasWeather then
                -- Verify if the running weather type matches the global tracker
                local ok, retData = sector:invokeFunction(scriptPath, "secure")
                if ok == 0 and retData and retData.type ~= weather.type then
                    sector:removeScript(scriptPath)
                    overwrite = true
                end
            end
            
            if not hasWeather or overwrite then
                -- Calculate remaining duration
                local expiry = weather.expiry or -1
                local remaining = expiry - Server().unpausedRuntime
                if expiry == -1 then
                    remaining = -1
                end
                
                if remaining > 0 or remaining == -1 then
                    sector:addScriptOnce(scriptPath, weather.type, remaining)
                end
            end
        end
    end
end

function forceSectorCleanup()
    if onClient() then return end
    local sector = Sector()
    local scriptPath = "data/scripts/sector/cv_weather_controller.lua"
    if sector and sector:hasScript(scriptPath) then
        sector:removeScript(scriptPath)
    end
end
