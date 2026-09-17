local News = include("cosmicvaultnews")
local Schema = include("cosmicvaultnews_schema")

local CosmicVaultNewsAdapter = {}

local MUTABLE_FIELDS = {
    "title", "content", "category", "topic", "severity", "breaking", "author",
    "location", "audience", "lead", "expiresAt", "provenance",
}

function CosmicVaultNewsAdapter.StableId(prefix, rawIdentity)
    if type(prefix) ~= "string" or prefix == "" then return nil, "invalid_id" end
    local hash, hashError = Schema.StableHash(tostring(rawIdentity))
    if hashError then return nil, hashError end
    return prefix .. ":" .. hash, nil
end

function CosmicVaultNewsAdapter.Upsert(options)
    if not onServer() then return nil, "server_only" end
    if type(options) ~= "table" or type(options.eventId) ~= "string" then
        return nil, "invalid_arguments"
    end

    local request, copyError = Schema.DeepCopy(options)
    if copyError then return nil, copyError end
    request.schemaVersion = 2
    request.publisherId = "cosmic_vault"
    request.audience = request.audience or {mode = "galaxy"}
    request.provenance = request.provenance or {recordType = "vault_event", sourceRevision = 0}

    local articleId = "cosmic_vault:" .. request.eventId
    local existing, getError = News.GetArticle(articleId)
    if not existing and getError == "not_found" then return News.Publish(request) end
    if not existing then return nil, getError end
    if existing.state ~= "active" then return existing, nil, false end

    local patch = {}
    for _, field in ipairs(MUTABLE_FIELDS) do patch[field] = request[field] end
    local updated, updateError = News.Update(articleId, "cosmic_vault", existing.revision, patch)
    return updated, updateError, false
end

function CosmicVaultNewsAdapter.Resolve(eventId, outcome, state)
    if not onServer() then return nil, "server_only" end
    if type(eventId) ~= "string" then return nil, "invalid_arguments" end
    local articleId = "cosmic_vault:" .. eventId
    local existing, getError = News.GetArticle(articleId)
    if not existing then return nil, getError end
    if existing.state ~= "active" then return existing, nil end
    return News.Resolve(articleId, "cosmic_vault", existing.revision, {
        state = state or "resolved",
        outcome = outcome,
    })
end

return CosmicVaultNewsAdapter
