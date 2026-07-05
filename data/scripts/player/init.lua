
package.path = package.path .. ";data/scripts/lib/?.lua"

if onServer() then
    local player = Player()
    player:addScriptOnce("data/scripts/player/ui/cosmiccodex.lua")
    player:addScriptOnce("data/scripts/player/cosmicvaultcodex.lua")
    player:addScriptOnce("data/scripts/player/ui/cosmicconfigmenu.lua")
    player:addScriptOnce("data/scripts/player/cosmicvaultcinematic.lua")
end
