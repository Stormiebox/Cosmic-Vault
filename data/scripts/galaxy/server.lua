local CosmicVault_old_init = initialize
local CosmicVault_DialogueManager = "data/scripts/server/cosmicvaultdialogue_server.lua"

function initialize(...)
    if CosmicVault_old_init then CosmicVault_old_init(...) end
    include("cosmicvaultdebug").info("Cosmic Vault", "[CosmicVault] server.lua initialized! Attaching cosmicvaultnews_server.lua")
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultnews_server.lua")
    Galaxy():addScriptOnce(CosmicVault_DialogueManager)
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultterritory_server.lua")
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultweather_server.lua")
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultriftescalation_server.lua")
    Galaxy():addScriptOnce("data/scripts/server/cosmicvaultmetrics_server.lua")
    if not Galaxy():hasScript(CosmicVault_DialogueManager) then
        include("cosmicvaultdebug").error("CosmicVault", "Dialogue manager failed to attach.")
    end
end
