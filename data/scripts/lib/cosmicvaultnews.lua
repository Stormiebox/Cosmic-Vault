package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicvaultdebug")

-- namespace CosmicVaultNews
CosmicVaultNews = {}

-- Publish a news article globally. Can be called from any server script.
-- article format: { title = "...", content = "...", category = "Economy|War|Event" }
function CosmicVaultNews.publishArticle(article)
    if not onServer() then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("CosmicVaultNews", "Articles can only be published from the server.")
        end
        return
    end
    
    if not article or type(article) ~= "table" or not article.title or not article.content then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("CosmicVaultNews", "Invalid article format.")
        end
        return
    end

    -- Clean Avorion translation hints (e.g. /* faction name */) from the title and content
    article.title = string.gsub(article.title, "%s*/%*.-%*/%s*", "")
    article.content = string.gsub(article.content, "%s*/%*.-%*/%s*", "")

    local server = Server()
    if server then
        local ok, err = pcall(function() server:sendCallback("onCCNewsPublishArticle", article) end)
        if not ok and CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("CosmicVaultNews", "Failed to publish article via callback: " .. tostring(err))
        end
    end
end

-- Get all published news articles on the client
function CosmicVaultNews.getPublishedNews()
    -- Since getPublishedNews would be synchronous but client-server boundary doesn't allow returning values directly,
    -- the UI should instead rely on the `cosmicvaultnews_server.lua` sync state.
    -- Alternatively, the UI tab can just use global table injected by the server script.
    -- But since this is a library, let's keep it simple.
    
    -- In Avorion, if we include the server script file directly on the client, it might not have the state.
    -- We'll let the UI tab do a custom request or read from a known global.
end

return CosmicVaultNews
