local cv_old_galaxy_init = initialize
function initialize(...)
    if cv_old_galaxy_init then cv_old_galaxy_init(...) end

    if onServer() then
        -- Attach the Cosmic Vault Faction Indexer to the Galaxy so it runs continuously in the background
        -- and populates the Server() key-value store.
        Galaxy():addScriptOnce("data/scripts/server/background/cosmicvaultfactionindex.lua")
    end
end
