package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultframework")

-- namespace CosmicVaultTask
CosmicVaultTask = CosmicVaultTask or {}
local _tasks = {}

--[[
    Cosmic Vault Task Scheduler API
    Allows modders to run intensive Lua operations across multiple server ticks using Coroutines,
    preventing massive TPS drops or server hangs.
]]

--- Runs a coroutine task asynchronously
-- @param taskName (string) Unique task name
-- @param func (function) The coroutine function
function CosmicVaultTask.RunAsync(taskName, taskFunc, ...)
    if type(taskFunc) ~= "function" then
        if CosmicVaultDebug then CosmicVaultDebug.error("CosmicVault-Task", "taskFunc must be a function") end
        return false
    end

    local co = coroutine.create(taskFunc)
    _tasks[taskName] = {
        co = co,
        args = {...},
        status = "running"
    }

    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicVault-Task", "Started Async Task: %s", taskName)
    end
    
    -- Run first step immediately
    local success, err = coroutine.resume(co, ...)
    if not success then
        if CosmicVaultDebug then CosmicVaultDebug.error("CosmicVault-Task", "Task %s failed: %s", taskName, tostring(err)) end
        _tasks[taskName] = nil
        return false
    end
    
    return true
end

--- Yields the current task for a specific duration
-- @param duration (number) Yield duration in seconds
function CosmicVaultTask.Yield()
    coroutine.yield()
end

--- Updates all running tasks (Should be called in an update loop)
-- @param timeStep (number) The time step
function CosmicVaultTask.Update(timeStep)
    for name, task in pairs(_tasks) do
        if coroutine.status(task.co) == "dead" then
            _tasks[name] = nil
            if CosmicVaultDebug and CosmicVaultDebug.info then
                CosmicVaultDebug.info("CosmicVault-Task", "Finished Async Task: %s", name)
            end
        else
            local success, err = coroutine.resume(task.co)
            if not success then
                if CosmicVaultDebug then CosmicVaultDebug.error("CosmicVault-Task", "Task %s failed: %s", name, tostring(err)) end
                _tasks[name] = nil
            end
        end
    end
end

--- Cancels a running task
-- @param taskName (string) The task name
function CosmicVaultTask.CancelTask(taskName)
    if not taskName then return end
    if _tasks[taskName] then
        _tasks[taskName] = nil
        return true
    end
    return false
end

--- Gets all running tasks
-- @return (table) List of running tasks
function CosmicVaultTask.GetRunningTasks()
    local active = {}
    for name, _ in pairs(_tasks) do
        table.insert(active, name)
    end
    return active
end

if CosmicVaultFramework and CosmicVaultFramework.registerModule then
    CosmicVaultFramework.registerModule("CosmicVaultTask", {version = "1.0.0"})
end

return CosmicVaultTask
