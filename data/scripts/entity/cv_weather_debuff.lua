-- namespace CosmicVaultLegacyWeatherDebuff
CosmicVaultLegacyWeatherDebuff = {}

local function cleanUp()
    if not onServer() then return end
    if not Entity() then return end
    -- Removing this script lets Avorion discard only bonuses owned by this
    -- script instance. A broad bonus wipe would also erase unrelated buffs.
    terminate()
end

function CosmicVaultLegacyWeatherDebuff.initialize()
    cleanUp()
end

function CosmicVaultLegacyWeatherDebuff.getUpdateInterval()
    return 5
end

function CosmicVaultLegacyWeatherDebuff.updateServer()
    cleanUp()
end

function CosmicVaultLegacyWeatherDebuff.restore()
    cleanUp()
end
