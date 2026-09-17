-- This fragment extends the vanilla library after Avorion has defined RiftMissionUT.
-- It deliberately has no trailing return; the virtual file system owns that export.
local cv_originalShowMissionAccomplished = RiftMissionUT.showMissionAccomplished

function RiftMissionUT.showMissionAccomplished(brief, arguments)
    if onServer() then
        pcall(function()
            local player = Player()
            local sector = Sector()
            if player and sector then
                local riftDepth = sector:getValue("rift_depth")
                if type(riftDepth) == "number" and riftDepth >= 50 then
                    local sectorSeed = tostring(sector.seed)
                    local x, y = sector:getCoordinates()
                    local eventId = "extraction:" .. tostring(player.index)
                        .. ":" .. sectorSeed .. ":" .. tostring(riftDepth)
                    include("cosmicvaultrift").ReportDeepExtraction(eventId, {
                        playerIndex = player.index,
                        sectorSeed = sectorSeed,
                        riftDepth = riftDepth,
                        x = x,
                        y = y
                    })
                end
            end
        end)
    end

    return cv_originalShowMissionAccomplished(brief, arguments)
end
