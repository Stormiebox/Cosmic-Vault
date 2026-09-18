
-- include() does not search data/scripts/lib/ by default; both entries are
-- needed so bare includes like "utility" (in lib/) and subdirectory-qualified
-- ones like "player/codex/infoCv" both resolve. Every sibling *codex.lua in
-- the other Cosmic mods carries both lines.
package.path = package.path .. ";data/scripts/lib/?.lua"
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
