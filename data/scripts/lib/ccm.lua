package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CCM
CCM = CCM or {}

local registries = {}
local bindings = {}

function CCM.register(namespace, configDef)
    registries[namespace] = configDef
end

function CCM.getRegistry(namespace)
    return registries[namespace]
end

function CCM.getAllRegistries()
    return registries
end

function CCM.bind(namespace)
    if bindings[namespace] then return bindings[namespace] end

    local binding = {}

    function binding.get(key)
        if onServer() then
            local sv = Server()
            if sv then
                local dbKey = "ccm_" .. namespace .. "_" .. key
                local val = sv:getValue(dbKey)
                if val ~= nil then
                    return val
                end
            end
        end
        
        -- fallback to default if registered
        local reg = registries[namespace]
        if reg and reg.pages then
            for _, page in ipairs(reg.pages) do
                for _, opt in ipairs(page.options) do
                    if opt.key == key then
                        return opt.default
                    end
                end
            end
        end
        return nil
    end

    bindings[namespace] = binding
    return binding
end

return CCM
