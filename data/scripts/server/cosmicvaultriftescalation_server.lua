package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("randomext")

-- namespace CosmicVaultRiftEscalation
CosmicVaultRiftEscalation = {}
local self = CosmicVaultRiftEscalation

function CosmicVaultRiftEscalation.initialize()
    if onServer() then
        Server():registerCallback("onRiftGuardianDestroyed", "onRiftGuardianDestroyed")
        Server():registerCallback("onRiftExtractionDepth50", "onRiftExtractionDepth50")
    end
end

function CosmicVaultRiftEscalation.onRiftGuardianDestroyed(entityIdStr)
    if not onServer() then return end
    local server = Server()
    local kills = server:getValue("cv_rift_guardian_kills")
    if type(kills) ~= "number" then kills = 0 end
    server:broadcastChatMessage("System"%_T, ChatMessageType.Warning, "WARNING: Global Xsotan aggression rising. A Rift Guardian has been destroyed. Escalation Level: %1%"%_T, tostring(kills))
    
    local cvn = include("cosmicvaultnews")
    cvn.publishArticle({
        title = "Rift Guardian Down",
        category = "Event",
        content = "A Rift Guardian has been destroyed. Global Xsotan aggression rising. Escalation Level: " .. kills
    })
end

function CosmicVaultRiftEscalation.onRiftExtractionDepth50(playerIndex)
    if not onServer() then return end
    local server = Server()
    local extractions = server:getValue("cv_rift_extractions")
    if type(extractions) ~= "number" then extractions = 0 end
    server:broadcastChatMessage("System"%_T, ChatMessageType.Warning, "WARNING: Subspace anomalies detected. A deep rift extraction has succeeded. Escalation Level: %1%"%_T, tostring(extractions))
    
    local cvn = include("cosmicvaultnews")
    cvn.publishArticle({
        title = "Deep Rift Extraction",
        category = "Event",
        content = "Subspace anomalies detected. A deep rift extraction has succeeded. Escalation Level: " .. extractions
    })
end

function CosmicVaultRiftEscalation.getUpdateInterval()
    return 60 -- Every minute
end

function CosmicVaultRiftEscalation.updateServer(timeStep)
    local server = Server()
    local kills = server:getValue("cv_rift_guardian_kills")
    if type(kills) ~= "number" then kills = 0 end
    local extractions = server:getValue("cv_rift_extractions")
    if type(extractions) ~= "number" then extractions = 0 end
    
    local escalationLevel = kills + (extractions * 0.5)
    
    if escalationLevel > 10 then
        -- Scale vanilla Xsotan aggression and attack volume
        -- 10% chance every minute per escalation level above 10
        local chance = math.min(0.5, (escalationLevel - 10) * 0.05)
        if random():test(chance) then
            -- Trigger random alien attack for online players
            for _, player in pairs({server:getOnlinePlayers()}) do
                local attackType = random():getInt(1, 3)
                -- 3 is also a valid type but is less common. Use 0, 1, or 2 for standard attacks.
                attackType = random():getInt(0, 2)
                player:addScriptOnce("data/scripts/player/events/alienattack.lua", attackType)
            end
            server:broadcastChatMessage("System"%_T, ChatMessageType.Warning, "CRITICAL: Global Rift Escalation Threshold Reached. Xsotan swarms converging galaxy-wide!"%_T)
            
            local cvn = include("cosmicvaultnews")
            cvn.publishArticle({
                title = "Global Rift Escalation",
                category = "Crisis",
                content = "Global Rift Escalation Threshold Reached. Xsotan swarms converging galaxy-wide!"
            })
            
            -- Reset some escalation after a massive attack to create waves instead of constant spam
            server:setValue("cv_rift_guardian_kills", math.max(0, kills - 2))
            server:setValue("cv_rift_extractions", math.max(0, extractions - 2))
        end
    end
end

function getUpdateInterval()
    return CosmicVaultRiftEscalation.getUpdateInterval()
end

function initialize()
    CosmicVaultRiftEscalation.initialize()
end

function updateServer(timeStep)
    CosmicVaultRiftEscalation.updateServer(timeStep)
end
