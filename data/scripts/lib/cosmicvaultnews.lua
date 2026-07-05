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
    
    if not article or type(article) ~= "table" or type(article.title) ~= "string" or type(article.content) ~= "string" then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("CosmicVaultNews", "Invalid article format or types.")
        end
        return
    end

    -- Enforce default category
    article.category = article.category or "General"

    -- Clean Avorion translation hints (e.g. /* faction name */) from the title and content
    article.title = string.gsub(article.title, "%s*/%*.-%*/%s*", "")
    article.content = string.gsub(article.content, "%s*/%*.-%*/%s*", "")

    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicVaultNews", "Publishing %s News: %s", article.category, article.title)
    end

    local server = Server()
    if server then
        server:sendCallback("onCCNewsPublishArticle", article)
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
