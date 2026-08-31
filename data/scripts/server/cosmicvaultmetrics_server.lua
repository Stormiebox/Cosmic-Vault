
local CosmicVaultConfig = include("cosmicvaultconfig")

-- namespace CosmicVaultMetricsServer
CosmicVaultMetricsServer = {}

function CosmicVaultMetricsServer.initialize()
    if onServer() then
        Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")
    end
end

function CosmicVaultMetricsServer.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if player then
        player:registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function CosmicVaultMetricsServer.onSectorEntered(playerIndex, x, y, sectorChangeType)
    local cfg = CosmicVaultConfig and CosmicVaultConfig.get and CosmicVaultConfig.get()
    if cfg and cfg.sectorLoadMetrics then
        local msg = string.format("[CosmicVault-Metrics] Player %d entered sector at (%d, %d) - Type: %d", playerIndex, x, y, sectorChangeType or 0)
        print(msg)
    end
end


