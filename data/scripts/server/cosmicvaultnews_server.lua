package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")
include("randomext")

-- namespace CosmicVaultNewsServer
CosmicVaultNewsServer = {}
local self = CosmicVaultNewsServer

self.publishedNews = {} -- Array of news objects {title, content, category, timestamp}
self.needsPlayerNotification = false

function CosmicVaultNewsServer.initialize()
    -- Register to listen for any player requesting a news sync
    if onServer() then
        include("cosmicvaultdebug").info("Cosmic Vault", "[CosmicVaultNews] cosmicvaultnews_server.lua initialized! Registering callbacks.")
        Server():registerCallback("onCCNewsSyncRequest", "onSyncRequest")
        Server():registerCallback("onCCNewsPublishArticle", "onPublishArticle")
    end
end

local reporters = {
    "Jade", "Kaelen", "Lyra", "Dax", "Rylan", "Vex", "Elara", "Talon", "Nova", "Silas",
    "Zyx", "Corin", "Tali", "Jarek", "Reyna", "Orion", "Kass", "Vesper", "Thorne", "Anya",
    "Soren", "Kael", "Zander", "Nyx", "Kira",
    "Vance", "Elena", "Torin", "Sera", "Ronan", "Mila", "Cade", "Lira", "Gael", "Tess"
}

-- Server function to publish a new article globally
function CosmicVaultNewsServer.publishArticle(article)
    if not onServer() then return end
    include("cosmicvaultdebug").info("Cosmic Vault", "[CosmicVaultNews] Publishing new article: " .. tostring(article.title))
    article.timestamp = Server().unpausedRuntime
    if not article.author then
        article.author = reporters[random():getInt(1, #reporters)]
    end
    table.insert(self.publishedNews, 1, article) -- Insert at the beginning (newest first)

    -- Keep only the last 30 articles to prevent memory bloat
    if #self.publishedNews > 30 then
        table.remove(self.publishedNews)
    end

    -- Flag that players need to be notified. We do this in updateServer to avoid re-entrant VM deadlocks!
    self.needsPlayerNotification = true
end

-- Triggered via Server():sendCallback("onCCNewsSyncRequest", playerIndex)
function CosmicVaultNewsServer.onSyncRequest(playerIndex)
    if not onServer() then return end
    include("cosmicvaultdebug").info("Cosmic Vault", "[CosmicVaultNews] Received sync request via callback from player " .. tostring(playerIndex))

    -- Self-healing: If the server just started and has no news, ask mods to generate some
    if #self.publishedNews == 0 then
        include("cosmicvaultdebug").info("Cosmic Vault", "[CosmicVaultNews] News is empty, requesting seed...")
        Server():sendCallback("onCCNewsRequestSeed")
    end

    -- DO NOT push the news back here!
    -- This callback is triggered synchronously by cc_newsboard.lua.
    -- Calling invokeFunction back into cc_newsboard.lua creates a re-entrant VM deadlock and crashes the C++ engine!
    -- cc_newsboard.lua will fetch the news itself after this callback returns.
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

function CosmicVaultNewsServer.getNews()
    return self.publishedNews
end


function CosmicVaultNewsServer.restore(data)
    self.publishedNews = data.publishedNews or {}
end

function getUpdateInterval()
    return 1.0
end

function initialize()
    CosmicVaultNewsServer.initialize()
end

function updateServer(timeStep)
    if CosmicVaultNewsServer.needsPlayerNotification then
        CosmicVaultNewsServer.needsPlayerNotification = false
        for _, player in pairs({Server():getOnlinePlayers()}) do
            -- include("cosmicvaultdebug").info("Cosmic Vault", "[CosmicVaultNews] Attempting to notify online player " .. tostring(player.index))
            player:invokeFunction("player/ui/cc_newsboard.lua", "onNewsPublished")
        end
    end
end


function secure(...)
    if CosmicVaultNewsServer.secure then return CosmicVaultNewsServer.secure(...) end
end
function restore(...)
    if CosmicVaultNewsServer.restore then return CosmicVaultNewsServer.restore(...) end
end


-- Global Event Callbacks
function onSyncRequest(...)
    if CosmicVaultNewsServer.onSyncRequest then return CosmicVaultNewsServer.onSyncRequest(...) end
end
function onPublishArticle(...)
    if CosmicVaultNewsServer.onPublishArticle then return CosmicVaultNewsServer.onPublishArticle(...) end
end

return CosmicVaultNewsServer
