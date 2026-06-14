package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultEvents
CosmicVaultEvents = {}

local VAULT_PREFIX = "cosmic_event_"

--- Starts a galaxy-wide timed event
-- @param eventName (string) The unique name of the event
-- @param durationSeconds (int) How long the event should last in real unpaused server seconds
function CosmicVaultEvents.startEvent(eventName, durationSeconds)
    if not onServer() then return end
    
    local server = Server()
    local key = VAULT_PREFIX .. eventName
    local endTime = server.unpausedRuntime + durationSeconds
    
    server:setValue(key, endTime)
end

--- Manually ends a galaxy-wide event early
-- @param eventName (string) The unique name of the event
function CosmicVaultEvents.endEvent(eventName)
    if not onServer() then return end
    
    local server = Server()
    local key = VAULT_PREFIX .. eventName
    server:setValue(key, nil)
end

--- Checks if a galaxy-wide event is currently active natively
-- @param eventName (string) The unique name of the event
-- @return boolean
function CosmicVaultEvents.isEventActive(eventName)
    if not eventName then return false end
    local server = Server()
    local key = VAULT_PREFIX .. eventName
    local endTime = server:getValue(key)
    
    if endTime then
        if server.unpausedRuntime < endTime then
            return true
        else
            -- Event naturally expired, clean it up if we are on server
            if onServer() then
                server:setValue(key, nil)
            end
        end
    end
    
    return false
end

--- Gets the remaining time of an active event
-- @param eventName (string) The unique name of the event
-- @return int Seconds remaining, or 0 if inactive
function CosmicVaultEvents.getEventTimeRemaining(eventName)
    if not eventName then return 0 end
    local server = Server()
    local key = VAULT_PREFIX .. eventName
    local endTime = server:getValue(key)
    
    if endTime then
        local remaining = endTime - server.unpausedRuntime
        if remaining > 0 then
            return math.floor(remaining)
        end
    end
    
    return 0
end

return CosmicVaultEvents
