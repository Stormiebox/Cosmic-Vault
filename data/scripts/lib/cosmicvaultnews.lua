local Debug = include("cosmicvaultdebug")

-- namespace CosmicVaultNews
CosmicVaultNews = {}

local MANAGER_PATH = "data/scripts/server/cosmicvaultnews_server.lua"
local unpackValues = table.unpack or unpack

local function packValues(...)
    return {n = select("#", ...), ...}
end

local function reportError(message, ...)
    if Debug and Debug.error then Debug.error("CosmicVaultNews", message, ...) end
end

local function invokeManager(functionName, ...)
    if not onServer() then return nil, "server_only" end
    local galaxy = Galaxy()
    if not galaxy then return nil, "manager_unavailable" end

    local results = packValues(galaxy:invokeFunction(MANAGER_PATH, functionName, ...))
    if results[1] ~= 0 then
        reportError("Manager call %s failed with invoke status %s.", functionName, tostring(results[1]))
        return nil, "manager_unavailable"
    end
    return unpackValues(results, 2, results.n)
end

function CosmicVaultNews.RegisterPublisher(definition)
    return invokeManager("registerPublisher", definition)
end

function CosmicVaultNews.Publish(options)
    return invokeManager("publish", options)
end

function CosmicVaultNews.Update(articleId, publisherId, expectedRevision, patch)
    return invokeManager("updateArticle", articleId, publisherId, expectedRevision, patch)
end

function CosmicVaultNews.Resolve(articleId, publisherId, expectedRevision, resolution)
    return invokeManager("resolveArticle", articleId, publisherId, expectedRevision, resolution)
end

function CosmicVaultNews.GetArticle(articleId, options)
    return invokeManager("getArticle", articleId, options)
end

function CosmicVaultNews.Query(options)
    return invokeManager("query", options)
end

function CosmicVaultNews.GetSnapshot()
    return invokeManager("getSnapshot")
end

-- Compatibility wrapper for the original free-text article shape. The input is copied so
-- normalization and timestamp assignment can never modify the publisher's table.
function CosmicVaultNews.publishArticle(article)
    if not onServer() then
        reportError("Articles can only be published from the server.")
        return nil, "server_only"
    end
    if type(article) ~= "table" or type(article.title) ~= "string" or type(article.content) ~= "string" then
        reportError("Invalid legacy article format or types.")
        return nil, "invalid_arguments"
    end

    if article.schemaVersion == 2 and article.publisherId and article.eventId then
        return CosmicVaultNews.Publish(article)
    end

    local copy = {
        title = article.title,
        content = article.content,
        category = type(article.category) == "string" and article.category or "General",
        breaking = article.breaking == true,
        author = type(article.author) == "string" and article.author or nil,
        timestamp = type(article.timestamp) == "number" and article.timestamp or nil,
    }

    local record, err, created = invokeManager("publishArticle", copy)
    if err ~= "manager_unavailable" then return record, err, created end

    -- This is the one-release compatibility transport for publishers that execute during
    -- manager attachment ordering. Migrated v2 publishers do not use this callback.
    local server = Server()
    if server then
        server:sendCallback("onCCNewsPublishArticle", copy)
        return nil, "queued_legacy", false
    end
    return nil, "manager_unavailable"
end

-- Compatibility read shape: newest 30 audience-neutral articles.
function CosmicVaultNews.getPublishedNews()
    if not onServer() then
        reportError("getPublishedNews() only works server-side.")
        return {}
    end
    local news = invokeManager("getNews")
    return type(news) == "table" and news or {}
end

return CosmicVaultNews
