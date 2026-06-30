function RiftMissionUT.showMissionAccomplished(brief, arguments)
    if onServer() then
        local player = Player()
        if not player then return end

        player:sendChatMessage("", ChatMessageType.Information, "Objective accomplished!"%_T)
        player:sendChatMessage("", ChatMessageType.Information, brief, unpack(arguments or {}))

        -- Cosmic Vault - Global Rift Escalation tracking
        local riftDepth = Sector():getValue("rift_depth") or 0
        if riftDepth >= 50 then
            local server = Server()
            local count = server:getValue("cv_rift_extractions") or 0
            server:setValue("cv_rift_extractions", count + 1)
            server:sendCallback("onRiftExtractionDepth50", player.index)
        end

        invokeClientFunction(Player(), "showMissionAccomplished", brief, arguments)
        return
    end

    displayMissionAccomplishedText("RIFT EXPEDITION SUCCESSFUL"%_t, (brief or "")%_t % arguments)
    playSound("interface/mission-accomplished", SoundType.UI, 1)
end
