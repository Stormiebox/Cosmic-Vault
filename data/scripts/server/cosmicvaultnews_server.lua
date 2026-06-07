package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")

-- namespace CosmicVaultNewsServer
CosmicVaultNewsServer = {}
local self = CosmicVaultNewsServer

self.publishedNews = {} -- Array of news objects {title, content, category, timestamp}

function CosmicVaultNewsServer.initialize()
    -- Register to listen for any player requesting a news sync
    if onServer() then
        Server():registerCallback("onCCNewsSyncRequest", "onSyncRequest")
        Server():registerCallback("onCCNewsPublishArticle", "onPublishArticle")
    end
end

-- Server function to publish a new article globally
function CosmicVaultNewsServer.publishArticle(article)
    if not onServer() then return end
    
    article.timestamp = Server().unpausedRuntime
    table.insert(self.publishedNews, 1, article) -- Insert at the beginning (newest first)
    
    -- Keep only the last 30 articles to prevent memory bloat
    if #self.publishedNews > 30 then
        table.remove(self.publishedNews)
    end
    
-- Broadcast the new article to all connected clients by pushing it to their UI scripts
    for _, player in pairs({Server():getOnlinePlayers()}) do
        if player:hasScript("player/ui/cc_newsboard.lua") then
            -- We trigger the Server side of the Chronicle UI, which then bridges it down to its own client
            player:invokeFunction("player/ui/cc_newsboard.lua", "pushNewsSync", player.index, self.publishedNews)
        end
    end
end

-- Triggered via Server():sendCallback("onCCNewsSyncRequest", playerIndex)
function CosmicVaultNewsServer.onSyncRequest(playerIndex)
    if not onServer() then return end
    
    -- Self-healing: If the server just started and has no news, ask mods to generate some
    if #self.publishedNews == 0 then
        Server():sendCallback("onCCNewsRequestSeed")
    end

    local player = Player(playerIndex)
    if player and player:hasScript("player/ui/cc_newsboard.lua") then
        player:invokeFunction("player/ui/cc_newsboard.lua", "pushNewsSync", playerIndex, self.publishedNews)
    end
end

-- Triggered via Server():sendCallback("onCCNewsPublishArticle", article)
function CosmicVaultNewsServer.onPublishArticle(article)
    if not onServer() then return end
    CosmicVaultNewsServer.publishArticle(article)
end

function CosmicVaultNewsServer.secure()
    return {
        publishedNews = self.publishedNews
    }
end

function CosmicVaultNewsServer.restore(data)
    self.publishedNews = data.publishedNews or {}
end
