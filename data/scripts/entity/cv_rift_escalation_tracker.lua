-- namespace CosmicVaultRiftEscalationTracker
CosmicVaultRiftEscalationTracker = {}

local entityUuid

function CosmicVaultRiftEscalationTracker.initialize()
    if not onServer() then return end
    local entity = Entity()
    if not entity then return end
    entityUuid = entity.id.string
    entity:registerCallback("onDestroyed", "onDestroyed")
end

function CosmicVaultRiftEscalationTracker.onDestroyed()
    if not onServer() or type(entityUuid) ~= "string" or entityUuid == "" then return end
    include("cosmicvaultrift").ReportGuardianDestroyed(
        "guardian:" .. entityUuid,
        {entityUuid = entityUuid}
    )
end

function CosmicVaultRiftEscalationTracker.secure()
    return {entityUuid = entityUuid}
end

function CosmicVaultRiftEscalationTracker.restore(data)
    if type(data) == "table" and type(data.entityUuid) == "string" then
        entityUuid = data.entityUuid
    end
end
