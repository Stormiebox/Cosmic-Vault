package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")

-- namespace CosmicVaultNewsServer
CosmicVaultNewsServer = {}
local self = CosmicVaultNewsServer

self.publishedNews = {} -- Array of news objects {title, content, category, timestamp}

function CosmicVaultNewsServer.initialize()
    -- Register to listen for any player requesting a news sync
    if onServer() then
        print("[CosmicVaultNews] cosmicvaultnews_server.lua initialized! Registering callbacks.")
        Server():registerCallback("onCCNewsSyncRequest", "onSyncRequest")
        Server():registerCallback("onCCNewsPublishArticle", "onPublishArticle")
    end
end

-- Server function to publish a new article globally
function CosmicVaultNewsServer.publishArticle(article)
    if not onServer() then return end
    print("[CosmicVaultNews] Publishing new article: " .. tostring(article.title))
    article.timestamp = Server().unpausedRuntime
    table.insert(self.publishedNews, 1, article) -- Insert at the beginning (newest first)
    
    -- Keep only the last 30 articles to prevent memory bloat
    if #self.publishedNews > 30 then
        table.remove(self.publishedNews)
    end
    
-- Broadcast the new article to all connected clients by pushing it to their UI scripts
    for _, player in pairs({Server():getOnlinePlayers()}) do
        print("[CosmicVaultNews] Attempting to push to online player " .. tostring(player.index))
        -- We trigger the Server side of the Chronicle UI, which then bridges it down to its own client
        player:invokeFunction("cc_newsboard.lua", "pushNewsSync", player.index, self.publishedNews)
    end
end

-- Triggered via Server():sendCallback("onCCNewsSyncRequest", playerIndex)
function CosmicVaultNewsServer.onSyncRequest(playerIndex)
    if not onServer() then return end
    print("[CosmicVaultNews] Received sync request via callback from player " .. tostring(playerIndex))
    
    -- Self-healing: If the server just started and has no news, ask mods to generate some
    if #self.publishedNews == 0 then
        print("[CosmicVaultNews] News is empty, requesting seed...")
        Server():sendCallback("onCCNewsRequestSeed")
    end

    local player = Player(playerIndex)
    if player then
        print("[CosmicVaultNews] Invoking pushNewsSync on cc_newsboard.lua for player " .. tostring(playerIndex))
        player:invokeFunction("cc_newsboard.lua", "pushNewsSync", playerIndex, self.publishedNews)
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

function initialize()
    CosmicVaultNewsServer.initialize()
end
