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
end

function CosmicConfigMenu.onShow()
    self.fillTree()
end

function CosmicConfigMenu.fillTree()
    self.tree:clear()
    self.elements = {}
    
    pcall(include, "cosmicoverhaulconfig")
    pcall(include, "cosmicwarconfig")
    pcall(include, "cosmicchroniclesconfig")
    pcall(include, "cosmicstarfallconfig")
    pcall(include, "cosmicvaultconfig")

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
        local split = UIVerticalSplitter(rect, 10, 0, 0.5)
        
        local label = self.container:createLabel(split.left, opt.title, 14)
        label.tooltip = opt.description
        
        local currentValue = binding.get(opt.key)
        if currentValue == nil then currentValue = opt.default end
        
        if opt.type == "bool" then
            local cb = self.container:createCheckBox(split.right, "", "onValueChanged")
            cb.checked = currentValue
            self.elements[opt.key] = { ui = cb, type = opt.type, namespace = namespace }
        elseif opt.type == "number" then
            local tb = self.container:createTextBox(split.right, "onValueChanged")
            tb.text = tostring(currentValue)
            self.elements[opt.key] = { ui = tb, type = opt.type, namespace = namespace, min = opt.min, max = opt.max }
        end
    end
end

function CosmicConfigMenu.onValueChanged()
    self.applyBtn.active = true
end

function CosmicConfigMenu.onApplyPressed()
    if not self.applyBtn.active then return end
    
    for key, data in pairs(self.elements) do
        local val
        if data.type == "bool" then
            val = data.ui.checked
        elseif data.type == "number" then
            val = tonumber(data.ui.text)
            if val then
                if data.min and val < data.min then val = data.min end
                if data.max and val > data.max then val = data.max end
            else
                val = nil
            end
        end
        
        if val ~= nil then
            invokeServerFunction("syncCCMValue", data.namespace, key, val)
        end
    end
    
    self.applyBtn.active = false
    Player():sendChatMessage("", 0, "Settings applied successfully.")
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
