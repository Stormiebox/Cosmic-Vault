
local CosmicVault_old_init = initialize

function initialize(...)
    if CosmicVault_old_init then CosmicVault_old_init(...) end
    include("cosmicvaultdebug").info("Cosmic Vault", "[CosmicVault] server.lua initialized! Attaching cosmicvaultnews_server.lua")
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultnews_server.lua")
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultterritory_server.lua")
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultweather_server.lua")
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultriftescalation_server.lua")
end
