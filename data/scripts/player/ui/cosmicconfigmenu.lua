package.path = package.path .. ";data/scripts/lib/?.lua"

include("utility")
local ccm = include("ccm")
include("stringutility")
include("callable")

-- namespace CosmicConfigMenu
CosmicConfigMenu = {}
local self = CosmicConfigMenu

if onClient() then

self.tab = nil
self.tree = nil
self.container = nil
self.elements = {}
self.applyBtn = nil

self.captureMode = false
self.captureTarget = nil
self.captureTimeLeft = 0
self.captureIgnore = {}

function CosmicConfigMenu.initialize()
    self.tab = PlayerWindow():createTab("CCM"%_t, "data/textures/icons/CosmicConfigTab.png", "Cosmic Config"%_t)
    self.tab.onShowFunction = "onShow"

    local hsplit = UIHorizontalSplitter(Rect(self.tab.size), 10, 0, 0.1)
    
    local titleLabel = self.tab:createLabel(hsplit.top, "Cosmic Configuration Menu"%_t, 24)
    titleLabel.centered = true
    
    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.3)
    
    self.tree = self.tab:createTree(vsplit.left)
    
    local bottomSplit = UIHorizontalSplitter(vsplit.right, 10, 0, 0.9)
    
    self.container = self.tab:createScrollFrame(bottomSplit.top)
    
    self.applyBtn = self.tab:createButton(bottomSplit.bottom, "Apply Changes"%_t, "onApplyPressed")
    self.applyBtn.active = false

    Player():registerCallback("onPostRenderHud", "onPostRenderHud")
    Player():registerCallback("onGalaxyMapUpdate", "onGalaxyMapUpdate")
end

function CosmicConfigMenu.onShow()
    self.fillTree()
    
    local keysToRequest = {}
    for namespace, reg in pairs(ccm.getAllRegistries()) do
        if reg.pages then
            for _, page in ipairs(reg.pages) do
                for _, opt in ipairs(page.options) do
                    table.insert(keysToRequest, {namespace = namespace, key = opt.key})
                end
            end
        end
    end
    
    invokeServerFunction("requestCCMSync", keysToRequest)
end

function CosmicConfigMenu.receiveCCMSync(data)
    self.serverData = data
    self.refreshUI()
end

function CosmicConfigMenu.fillTree()
    self.tree:clear()
    self.elements = {}
    
    include("cosmicoverhaulconfig")
    include("cosmicwarconfig")
    include("cosmicvaultconfig")

    local registries = ccm.getAllRegistries()
    
    self.treeValues = {}
    for namespace, reg in pairs(registries) do
        local modIndex = self.tree:add(nil, namespace, "onEntrySelected", false, namespace)
        self.treeValues[modIndex] = namespace
        if reg.pages then
            for i, page in ipairs(reg.pages) do
                local pageIndex = self.tree:add(modIndex, page.title, "onEntrySelected", true, namespace .. "::" .. i)
                self.treeValues[pageIndex] = namespace .. "::" .. i
            end
        end
    end
end

function CosmicConfigMenu.onEntrySelected(index)
    self.tree.selectedIndex = index
    self.selectedValue = self.treeValues[index]
    self.refreshUI()
end

function CosmicConfigMenu.refreshUI()
    self.container:clear()
    self.elements = {}
    self.applyBtn.active = false
    
    local selected = self.tree.selectedIndex
    if not selected then return end
    
    local nodeValue = self.selectedValue
    if not nodeValue then return end
    
    local parts = string.split(nodeValue, "::")
    if #parts ~= 2 then return end
    
    local namespace = parts[1]
    local pageIndex = tonumber(parts[2])
    
    local reg = ccm.getRegistry(namespace)
    if not reg or not reg.pages or not reg.pages[pageIndex] then return end
    
    local page = reg.pages[pageIndex]
    local binding = ccm.bind(namespace)
    
    local lister = UIVerticalLister(Rect(vec2(0, 0), self.container.size), 10, 0)
    
    for _, opt in ipairs(page.options) do
        local rect = lister:placeCenter(vec2(self.container.size.x, 30))
        
        -- 3 column layout: Label (40%), Control (50%), Reset Button (10%)
        local split1 = UIVerticalSplitter(rect, 10, 0, 0.4)
        local leftPart = split1.left
        local split2 = UIVerticalSplitter(split1.right, 10, 0, 0.9)
        local rightPart = split2.left
        local resetPart = split2.right
        
        local label = self.container:createLabel(leftPart, opt.title, 14)
        local desc = opt.description or ""
        if opt.min and opt.max then
            desc = desc .. string.format("\n\n(Min: %s, Max: %s)", tostring(opt.min), tostring(opt.max))
        end
        label.tooltip = desc
        
        local currentValue = nil
        if self.serverData then
            currentValue = self.serverData[namespace .. "_" .. opt.key]
        end
        if currentValue == nil then currentValue = opt.default end
        
        if opt.type == "bool" then
            local cb = self.container:createCheckBox(rightPart, "", "onValueChanged")
            cb.checked = currentValue
            self.elements[opt.key] = { ui = cb, type = opt.type, namespace = namespace, default = opt.default }
        elseif opt.type == "number" then
            if opt.min and opt.max then
                local steps = math.ceil(opt.max - opt.min)
                if steps > 200 then steps = 200 end
                if steps <= 0 then steps = 1 end
                local slider = self.container:createSlider(rightPart, opt.min, opt.max, steps, "", "onValueChanged")
                slider:setValueNoCallback(currentValue)
                self.elements[opt.key] = { ui = slider, type = "slider", namespace = namespace, min = opt.min, max = opt.max, default = opt.default }
            else
                local tb = self.container:createTextBox(rightPart, "onValueChanged")
                tb.text = tostring(currentValue)
                self.elements[opt.key] = { ui = tb, type = "number", namespace = namespace, min = opt.min, max = opt.max, default = opt.default }
            end
        elseif opt.type == "keybind" then
            if type(currentValue) ~= "number" then currentValue = ccm.keys.UNBOUND end
            local btn = self.container:createButton(rightPart, ccm.keys.nameForCombo(currentValue), "onKeybindPressed")
            self.elements[opt.key] = { ui = btn, type = "keybind", namespace = namespace, default = opt.default, packed = currentValue, key = opt.key }
        end
        
        local resetBtn = self.container:createButton(resetPart, "", "onResetOption")
        resetBtn.icon = "data/textures/icons/anticlockwise-rotation.png"
        resetBtn.tooltip = "Reset to Default"%_t
        self.elements[opt.key].resetBtn = resetBtn
    end
end

function CosmicConfigMenu.onValueChanged()
    self.applyBtn.active = true
end

function CosmicConfigMenu.onResetOption(btn)
    for key, data in pairs(self.elements) do
        if data.resetBtn and data.resetBtn.index == btn.index then
            if data.type == "bool" then
                data.ui:setCheckedNoCallback(data.default)
            elseif data.type == "slider" then
                data.ui:setValueNoCallback(data.default)
            elseif data.type == "number" then
                data.ui.text = tostring(data.default)
            elseif data.type == "keybind" then
                local def = data.default
                if type(def) ~= "number" then def = ccm.keys.UNBOUND end
                data.packed = def
                data.ui.caption = ccm.keys.nameForCombo(def)
            end
            self.onValueChanged()
            break
        end
    end
end

function CosmicConfigMenu.onApplyPressed()
    if not self.applyBtn.active then return end
    
    for key, data in pairs(self.elements) do
        local val
        if data.type == "bool" then
            val = data.ui.checked
        elseif data.type == "slider" then
            val = data.ui.value
        elseif data.type == "number" then
            val = tonumber(data.ui.text)
            if val then
                if data.min and val < data.min then val = data.min end
                if data.max and val > data.max then val = data.max end
            else
                val = nil
            end
        elseif data.type == "keybind" then
            val = data.packed
        end
        
        if val ~= nil then
            invokeServerFunction("syncCCMValue", data.namespace, key, val)
        end
    end
    
    self.applyBtn.active = false
    Player():sendChatMessage("", 0, "Settings applied successfully.")
end

-- Keybind capture logic
function CosmicConfigMenu.onKeybindPressed(btn)
    for key, data in pairs(self.elements) do
        if data.type == "keybind" and data.ui.index == btn.index then
            self.startCapture(data)
            break
        end
    end
end

function CosmicConfigMenu.startCapture(elementData)
    if not elementData then return end
    self.captureMode = true
    self.captureTarget = elementData
    self.captureTimeLeft = 8.0
    self.captureIgnore = {}

    local kb = Keyboard()
    for _, sc in ipairs(ccm.keys.captureCandidates()) do
        if kb:keyPressed(sc) then self.captureIgnore[sc] = true end
    end

    elementData.ui.caption = "Press a key... (Esc to cancel)"%_t
end

function CosmicConfigMenu.commitCapture(packed)
    if self.captureTarget then
        self.captureTarget.packed = packed
        self.captureTarget.ui.caption = ccm.keys.nameForCombo(packed)
        self.onValueChanged()
    end
    self.captureMode = false
    self.captureTarget = nil
end

function CosmicConfigMenu.cancelCapture()
    if self.captureTarget then
        self.captureTarget.ui.caption = ccm.keys.nameForCombo(self.captureTarget.packed)
    end
    self.captureMode = false
    self.captureTarget = nil
end

function CosmicConfigMenu.runCaptureTick(timeStep)
    self.captureTimeLeft = self.captureTimeLeft - (timeStep or 0.016)
    if self.captureTimeLeft <= 0 then self.cancelCapture(); return end

    local kb = Keyboard()
    if kb:keyDown(41) then self.cancelCapture(); return end -- Escape

    for sc in pairs(self.captureIgnore) do
        if not kb:keyPressed(sc) then self.captureIgnore[sc] = nil end
    end

    for _, sc in ipairs(ccm.keys.captureCandidates()) do
        if not self.captureIgnore[sc] and kb:keyDown(sc) then
            local packed = sc
            local lctrl  = kb:keyPressed(ccm.keys.SC_LCTRL)
            local rctrl  = kb:keyPressed(ccm.keys.SC_RCTRL)
            local lshift = kb:keyPressed(ccm.keys.SC_LSHIFT)
            local rshift = kb:keyPressed(ccm.keys.SC_RSHIFT)
            local lalt   = kb:keyPressed(ccm.keys.SC_LALT)
            local ralt   = kb:keyPressed(ccm.keys.SC_RALT)

            if not lctrl and not rctrl and kb.controlPressed then
                lctrl = true
            end

            if lctrl  then packed = packed + ccm.keys.LCTRL  end
            if rctrl  then packed = packed + ccm.keys.RCTRL  end
            if lshift then packed = packed + ccm.keys.LSHIFT end
            if rshift then packed = packed + ccm.keys.RSHIFT end
            if lalt   then packed = packed + ccm.keys.LALT   end
            if ralt   then packed = packed + ccm.keys.RALT   end

            self.commitCapture(packed)
            return
        end
    end
end

function CosmicConfigMenu.handleRightClickClear()
    if not self.tab or not self.tab.visible then return end
    if not Mouse():mousePressed(MouseButton.Right) then return end

    for _, entry in pairs(self.elements) do
        if entry.type == "keybind" and entry.ui:isMouseOverAndUnobscured() then
            entry.packed = ccm.keys.UNBOUND
            entry.ui.caption = ccm.keys.nameForCombo(ccm.keys.UNBOUND)
            self.onValueChanged()
        end
    end
end

function CosmicConfigMenu.onPostRenderHud(state, timeStep)
    if self.captureMode then
        self.runCaptureTick(timeStep)
    end
    self.handleRightClickClear()

    local cvcfg = ccm.bind("CosmicVault")
    if cvcfg.isKeyComboDown("hotkeyConfigMenu") then
        local pw = PlayerWindow()
        if pw and self.tab then
            pw:show()
            if pw.selectTab then
                pw:selectTab(self.tab)
            elseif pw.activateTab then
                pw:activateTab(self.tab)
            end
        end
    end
end

function CosmicConfigMenu.onGalaxyMapUpdate(timeStep)
    self.onPostRenderHud(0, timeStep)
end

end -- onClient()

function CosmicConfigMenu.syncCCMValue(namespace, key, value)
    local admin = false
    if callingPlayer then
        local p = Player(callingPlayer)
        if p and p.index then
            local s = Server()
            admin = s:hasAdminPrivileges(p)
        end
    end
    
    if admin then
        Server():setValue("ccm_" .. namespace .. "_" .. key, value)
    end
end
callable(CosmicConfigMenu, "syncCCMValue")

function CosmicConfigMenu.requestCCMSync(keys)
    local s = Server()
    local data = {}
    if type(keys) == "table" then
        for _, item in ipairs(keys) do
            if type(item) == "table" and item.namespace and item.key then
                local val = s:getValue("ccm_" .. item.namespace .. "_" .. item.key)
                data[item.namespace .. "_" .. item.key] = val
            end
        end
    end
    invokeClientFunction(Player(callingPlayer), "receiveCCMSync", data)
end
callable(CosmicConfigMenu, "requestCCMSync")
