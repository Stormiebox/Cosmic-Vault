
include("cosmicvaultdebug")

-- namespace CosmicVaultNews
CosmicVaultNews = {}

-- Publish a news article globally. Can be called from any server script.
-- article format: {
--     title = "...", content = "...",         -- required, both strings
--     category = "Economy|War|Event|...",     -- optional, defaults to "General"; any free-text
--         value is accepted -- consuming UIs (e.g. Cosmic Chronicles' News Board) are expected
--         to group/normalize categories themselves rather than this API enforcing a fixed enum,
--         since the set of categories legitimately grows as more mods hook into this API.
--     breaking = true|false,                  -- optional, defaults to false. Marks the article
--         as a galaxy-shaking event worth interrupting the player for (a dedicated UI banner,
--         an immediate chat alert, etc., entirely at the consuming UI's discretion -- this API
--         only carries the flag through). Reserve this for genuinely rare, major events; a
--         "breaking" article every few minutes defeats the point.
-- }
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

    -- Normalize to a real boolean so consuming UIs can trust the field's type rather than
    -- treating any truthy value (a string, a number) as "breaking".
    article.breaking = article.breaking == true

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

-- Synchronously reads the currently published news articles. Server-side only: this is a
-- direct in-process call into cosmicvaultnews_server.lua's own storage, so it only ever
-- reflects the CALLER's own side. A client-side caller cannot get server news this way --
-- there is no synchronous client/server call in Avorion's API -- and must instead do what
-- Cosmic Chronicles' News Board does: invokeServerFunction() a request, then receive the
-- result via invokeClientFunction() on the reply.
function CosmicVaultNews.getPublishedNews()
    if not onServer() then
        if CosmicVaultDebug and CosmicVaultDebug.error then
            CosmicVaultDebug.error("CosmicVaultNews", "getPublishedNews() only works server-side; a client must request a sync from its own UI script instead.")
        end
        return {}
    end

    local galaxy = Galaxy()
    if not galaxy then return {} end

    local ok, news = galaxy:invokeFunction("cosmicvaultnews_server.lua", "getNews")
    if ok == 0 and type(news) == "table" then
        return news
    end
    return {}
end

return CosmicVaultNews
