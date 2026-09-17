
-- namespace CosmicVaultMission
CosmicVaultMission = {}

--- Easily constructs a standard Bulletin Board post for custom missions
-- @param title (string) Title of the mission
-- @param description (string) Brief description
-- @param difficulty (string) "Easy", "Normal", "Hard"
-- @param rewardText (string) Text to show for the reward
-- @param scriptPath (string) The path to the mission script (e.g. "data/scripts/player/missions/mymission.lua")
-- @param icon (string) Optional icon path
-- @return table A formatted bulletin object that can be returned to `getBulletins()`
function CosmicVaultMission.createBulletin(title, description, difficulty, rewardText, scriptPath, args, icon)
    if type(title) ~= "string" or type(description) ~= "string" or type(scriptPath) ~= "string" then return nil end
    local bulletin = {
        brief = title,
        description = description,
        difficulty = difficulty or "Normal",
        reward = rewardText,
        script = scriptPath,
        arguments = args or {},
        formatArguments = {},
        msg = description,
        icon = icon or "data/textures/icons/mission.png"
    }
    return bulletin
end

--- Extended bulletin builder -- additive alongside createBulletin() above, for callers
-- that need `formatArguments` (dynamic reward-text substitution, e.g. "${reward}") or
-- `onAccept` (an inline script run the moment a player accepts, e.g. an NPC chat message)
-- that the original's fixed parameter list doesn't support. Cosmic War's own 25+ mission
-- files currently build this exact superset shape by hand; this is the shared version any
-- Cosmic mod's bulletin-board missions can adopt instead.
-- @param opts (table) {
--     title, description, difficulty, rewardText, scriptPath, icon -- same as createBulletin()
--     args (table|nil) -- positional arguments passed to the mission script's initialize()
--     formatArguments (table|nil) -- named substitutions for `${key}`-style tokens in rewardText/description
--     msg (string|nil) -- defaults to `description` if omitted, matching createBulletin()'s behavior
--     onAccept (string|nil) -- inline Lua source run as `function(self, player) ... end` when accepted
-- }
-- @return table|nil a formatted bulletin object, or nil if a required field is missing/wrong type
function CosmicVaultMission.createBulletinEx(opts)
    opts = opts or {}
    if type(opts.title) ~= "string" or type(opts.description) ~= "string" or type(opts.scriptPath) ~= "string" then return nil end

    return {
        brief = opts.title,
        description = opts.description,
        difficulty = opts.difficulty or "Normal",
        reward = opts.rewardText,
        script = opts.scriptPath,
        arguments = opts.args or {},
        formatArguments = opts.formatArguments or {},
        msg = opts.msg or opts.description,
        icon = opts.icon or "data/textures/icons/mission.png",
        onAccept = opts.onAccept
    }
end

--- Safely attempts to sync a mission state objective across the UI
-- @param missionId (string) The mission UUID or identifier
-- @param objectiveText (string) The new objective text to display
function CosmicVaultMission.updateMissionObjective(missionId, objectiveText)
    if not missionId or not objectiveText then return end
    if onServer() then
        local player = Player()
        if not player then return end
        player:invokeFunction(missionId, "setObjective", objectiveText)
    end
end

--- Resolves the mission, granting rewards and cleaning up the script safely
-- @param missionId (string) The mission UUID or identifier
-- @param creditReward (int) Number of credits to reward
-- @param reputationReward (int) Reputation to reward with the local faction
function CosmicVaultMission.completeMission(missionId, creditReward, reputationReward)
    if not onServer() then return end
    if not missionId then return end
    local player = Player()
    if not player then return end
    
    if creditReward and creditReward > 0 then
        player:receiveWithoutNotify("Mission Reward", creditReward, {})
        player:sendChatMessage("System", 0, "Received %s Credits for completing a mission.", tostring(creditReward))
    end

    if reputationReward and reputationReward > 0 then
        local sector = Sector()
        -- A missing sector here (e.g. no current sector context) should only skip the
        -- reputation grant, not the mission-cleanup removeScript call below -- this used
        -- to `return` the whole function, silently leaving the mission script attached.
        if sector then
            local x, y = sector:getCoordinates()
            local faction = Galaxy():getControllingFaction(x, y)
            if faction then
                Galaxy():changeFactionRelations(Faction(player.index), faction, reputationReward)
            end
        end
    end

    -- Only real for a caller whose missionId is an actual attached script path (e.g. a
    -- bulletin-board mission's own scriptPath); a semantic id string with no matching
    -- script is safely skipped.
    if player:hasScript(missionId) then
        player:removeScript(missionId)
    end
end

--- Fails the mission and cleans up the script safely
-- @param missionId (string) The mission UUID or identifier
function CosmicVaultMission.failMission(missionId)
    if not onServer() then return end
    if type(missionId) ~= "string" then return end
    local player = Player()
    if not player then return end

    player:sendChatMessage("System", 1, "Mission Failed.")
    if player:hasScript(missionId) then
        player:removeScript(missionId)
    end
end

--- Grants an item reward directly to the player's inventory
-- @param itemTemplate (table/SystemUpgradeTemplate/TurretTemplate) The item to grant
-- @param amount (int) The amount to grant (default: 1)
function CosmicVaultMission.grantItemReward(itemTemplate, amount)
    if not onServer() then return end
    if not itemTemplate then return end
    local player = Player()
    if not player then return end

    local qty = tonumber(amount) or 1
    player:getInventory():add(itemTemplate, qty)
end

return CosmicVaultMission
