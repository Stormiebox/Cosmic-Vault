package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

function initialize()
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end

function onDestroyed()
    if onServer() then
        local server = Server()
        local count = server:getValue("cv_rift_guardian_kills") or 0
        server:setValue("cv_rift_guardian_kills", count + 1)
        
        server:sendCallback("onRiftGuardianDestroyed", Entity().id.string)
    end
end
