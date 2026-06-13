local CosmicVault_old_init = initialize

function initialize(...)
    if CosmicVault_old_init then CosmicVault_old_init(...) end
    print("[CosmicVault] server.lua initialized! Attaching cosmicvaultnews_server.lua")
    Galaxy():addScriptOnce("server/cosmicvaultnews_server.lua")
    Galaxy():addScriptOnce("server/cosmicvaultterritory_server.lua")
end
