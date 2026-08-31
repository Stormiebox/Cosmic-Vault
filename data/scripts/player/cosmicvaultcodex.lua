
-- include() only searches data/scripts/lib/ by default; a subdirectory-qualified
-- path like "player/codex/infoCv" needs this pattern added first, or it fails
-- with "module not found" (see vanilla dlc/rift/lib/riftguardian.lua for the
-- same requirement).
package.path = package.path .. ";data/scripts/?.lua"

include("utility")

function initialize()
    if onClient() then
        Player():registerCallback("onCosmicCodexGatherData", "onCosmicCodexGatherData")
    end
end

function onCosmicCodexGatherData()
    include("player/codex/infoCv")
    infoCv_injectToCodex()
end
