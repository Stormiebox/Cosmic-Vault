package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CosmicVaultMission
CosmicVaultMission = {}

--- Easily constructs a standard Bulletin Board post for custom missions
-- @param title (string) Title of the mission
-- @param description (string) Brief description
-- @param difficulty (string) "Easy", "Normal", "Hard"
-- @param rewardText (string) Text to show for the reward
-- @param scriptPath (string) The path to the mission script (e.g. "data/scripts/player/missions/mymission.lua")
-- @param args (table) Any script arguments
-- @return table A formatted bulletin object that can be returned to `getBulletins()`
function CosmicVaultMission.createBulletin(title, description, difficulty, rewardText, scriptPath, args)
    if not title or not description or not scriptPath then return nil end
    local bulletin = {
        brief = title,
        description = description,
        difficulty = difficulty or "Normal",
        reward = rewardText,
        script = scriptPath,
        arguments = args or {},
        formatArguments = {},
        msg = description
    }
    return bulletin
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
        player:receive("Mission Reward", creditReward)
    end

    if reputationReward and reputationReward > 0 then
        local sector = Sector()
        if not sector then return end
        
        local x, y = sector:getCoordinates()
        local faction = Galaxy():getControllingFaction(x, y)
        if faction then
            Galaxy():changeFactionRelations(Faction(player.index), faction, reputationReward)
        end
    end

    -- Cleanly remove the mission script from the player
    player:removeScript(missionId)
end

return CosmicVaultMission
