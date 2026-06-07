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
    
    -- Broadcast the new article to all connected clients
    broadcastInvokeClientFunction("receiveNewsUpdate", self.publishedNews)
end

-- Triggered via Server():sendCallback("onCCNewsSyncRequest", playerIndex)
function CosmicVaultNewsServer.onSyncRequest(playerIndex)
    if not onServer() then return end
    local player = Player(playerIndex)
    if player then
        player:invokeFunction("player/ui/cc_newsboard.lua", "receiveNews", self.publishedNews)
    end
end

-- Client receives the array
function CosmicVaultNewsServer.receiveNewsUpdate(newsArray)
    if not onClient() then return end
    self.publishedNews = newsArray
    -- Fire a client-side callback so any mod's UI can instantly update!
    if Client() then
        Client():sendCallback("onCosmicVaultNewsUpdated", newsArray)
    end
end
