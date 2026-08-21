package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CCM
CCM = CCM or {}

local registries = {}
local bindings = {}
local Keys = include("ccm_keycodes")

CCM.keys = Keys
CCM.UNBOUND = Keys.UNBOUND

function CCM.register(namespace, configDef)
    registries[namespace] = configDef
end

function CCM.getRegistry(namespace)
    return registries[namespace]
end

function CCM.getAllRegistries()
    return registries
end



local function readModifierState(c, kb)
    local lctrl  = kb:keyPressed(Keys.SC_LCTRL)
    local rctrl  = kb:keyPressed(Keys.SC_RCTRL)
    local lshift = kb:keyPressed(Keys.SC_LSHIFT)
    local rshift = kb:keyPressed(Keys.SC_RSHIFT)
    local lalt   = kb:keyPressed(Keys.SC_LALT)
    local ralt   = kb:keyPressed(Keys.SC_RALT)

    if not lctrl and not rctrl and kb.controlPressed then
        lctrl = c.lctrl
        rctrl = c.rctrl
    end

    return lctrl, rctrl, lshift, rshift, lalt, ralt
end

local function modifiersMatch(c, kb, mode)
    local lctrl, rctrl, lshift, rshift, lalt, ralt = readModifierState(c, kb)

    if mode == "loose" then
        if c.lctrl  and not lctrl  then return false end
        if c.rctrl  and not rctrl  then return false end
        if c.lshift and not lshift then return false end
        if c.rshift and not rshift then return false end
        if c.lalt   and not lalt   then return false end
        if c.ralt   and not ralt   then return false end
        return true
    end
    -- strict
    if c.lctrl  ~= lctrl  then return false end
    if c.rctrl  ~= rctrl  then return false end
    if c.lshift ~= lshift then return false end
    if c.rshift ~= rshift then return false end
    if c.lalt   ~= lalt   then return false end
    if c.ralt   ~= ralt   then return false end
    return true
end

function CCM.bind(namespace)
    if type(namespace) ~= "string" then return nil end
    if bindings[namespace] then return bindings[namespace] end

    local binding = {}

    function binding.get(key)
        if type(key) ~= "string" then return nil end
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
        
        if onClient() then
            local p = Player()
            if p then
                local dbKey = "ccm_" .. namespace .. "_" .. key
                local val = p:getValue(dbKey)
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

    function binding.isKeyComboDown(key, mode)
        if not onClient() then return false end
        if checkInputFocus and checkInputFocus() then return false end
        local packed = binding.get(key)
        if not packed or packed < 0 then return false end
        local c = Keys.unpack(packed)
        if c.scancode <= 0 then return false end
        local kb = Keyboard()
        if not modifiersMatch(c, kb, mode) then return false end
        return kb:keyPressed(c.scancode)
    end

    function binding.isKeyComboHeld(key, mode)
        if not onClient() then return false end
        if checkInputFocus and checkInputFocus() then return false end
        local packed = binding.get(key)
        if not packed or packed < 0 then return false end
        local c = Keys.unpack(packed)
        if c.scancode <= 0 then return false end
        local kb = Keyboard()
        if not modifiersMatch(c, kb, mode) then return false end
        return kb:keyDown(c.scancode)
    end

    bindings[namespace] = binding
    return binding
end

return CCM
