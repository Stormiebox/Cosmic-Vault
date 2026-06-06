package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")

-- namespace CosmicVaultNewsServer
CosmicVaultNewsServer = {}
local self = CosmicVaultNewsServer

self.publishedNews = {} -- Array of news objects {title, content, category, timestamp}

function CosmicVaultNewsServer.initialize()
    -- On initialize, maybe load persistent news if needed
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

-- Client requests sync when they open the UI or log in
function CosmicVaultNewsServer.sync()
    if onServer() then
        invokeClientFunction(Player(callingPlayer), "receiveNewsUpdate", self.publishedNews)
        return
    end
    if onClient() then
        invokeServerFunction("sync")
    end
end
callable(CosmicVaultNewsServer, "sync")

-- Specific targeted sync requested by player scripts
function CosmicVaultNewsServer.syncPlayer(playerIndex)
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
    -- If a UI script is listening, it can grab the news from the API
end
