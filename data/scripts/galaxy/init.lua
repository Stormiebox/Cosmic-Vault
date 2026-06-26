include("data/scripts/galaxy/init.lua")

if onServer() then
    -- Attach the Cosmic Vault Faction Indexer to the Galaxy so it runs continuously in the background
    -- and populates the Server() key-value store.
    Galaxy():addScriptOnce("data/scripts/server/background/cosmicvaultfactionindex.lua")
end
