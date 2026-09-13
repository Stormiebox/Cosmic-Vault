
if onServer() then return end

local LEGACY_PROBLEM_TYPE = "CosmicVaultWeather"
local cleaned = false

local function cleanUp()
    if cleaned then return end
    local player = Player()
    local craft = player and player.craft
    if not craft then return end
    removeShipProblem(LEGACY_PROBLEM_TYPE, craft.index)
    cleaned = true
    terminate()
end

function initialize()
    cleanUp()
end

function getUpdateInterval()
    return 1
end

function updateClient()
    cleanUp()
end

function onRemove()
    local player = Player()
    local craft = player and player.craft
    if craft then removeShipProblem(LEGACY_PROBLEM_TYPE, craft.index) end
end
