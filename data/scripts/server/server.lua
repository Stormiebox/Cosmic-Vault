local CosmicVault_old_init = initialize

function initialize(...)
    if CosmicVault_old_init then CosmicVault_old_init(...) end
    Server():addScriptOnce("server/cosmicvaultnews_server.lua")
end
