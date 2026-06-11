package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/ui/?.lua"

include("stringutility")
include("utility")
include("callable")

-- namespace CosmicCodex
CosmicCodex = {}
local self = CosmicCodex

if onClient() then

self.categories = {}
self.articles = {}
self.categoryCount = 0

self.tab = nil
self.tree = nil
self.titleLabel = nil
self.picture = nil
self.textField = nil
self.originalRect = nil

function CosmicCodex.initialize()
    self.tab = PlayerWindow():createTab("Cosmic Codex"%_t, "data/textures/icons/CosmicCodexTab.png", "Cosmic Codex"%_t)
    self.tab.onShowFunction = "onShow"

    local vsplit = UIVerticalSplitter(Rect(self.tab.size), 10, 0, 0.3)

    local lhsplit = UIHorizontalSplitter(vsplit.left, 10, 0, 0.5)
    lhsplit.topSize = 30

    self.searchTextBox = self.tab:createTextBox(lhsplit.top, "onSearchTextChanged")
    self.searchTextBox.backgroundText = "Search"%_t

    self.tree = self.tab:createTree(lhsplit.bottom)
    
    local hsplit = UIHorizontalSplitter(vsplit.right, 30, 0, 0.5)
    hsplit.topSize = 20

    local hsplit2 = UIHorizontalSplitter(hsplit.bottom, 10, 0, 0.60)

    local titleRect = hsplit.top
    local textRect = hsplit2.bottom

    self.titleLabel = self.tab:createLabel(titleRect, "Cosmic Codex"%_t, 30)

    self.originalRect = hsplit2.top
    self.picture = self.tab:createPicture(self.originalRect, "")
    self.picture.isIcon = false -- Prevents it from coloring black like icons
    
    self.backgroundBox = self.tab:createFrame(textRect)

    local text = "Welcome to the \\c(0d0)Cosmic Codex\\c()!\n\nThis is the central repository for all knowledge regarding the Cosmic Mod Series.\nSelect a category on the left to begin."%_t
    self.textField = self.tab:createTextField(textRect, text)
    self.textField.scrollable = true
    self.textField.font = FontType.Normal
    self.textField.fontSize = 14
    self.textField.fontColor = ColorRGB(0.7, 0.7, 0.7)
end

function CosmicCodex.onShow()
    self.fillTree()
end

function CosmicCodex.onSearchTextChanged(textBox)
    self.fillTree()
end

function CosmicCodex.fillTree()
    self.tree:clear()
    self.tree:setLevelStyle(0, 30, 18)
    self.categories = {}
    self.articles = {}
    self.categoryCount = 0

    self.refreshUI()

    -- Trigger other scripts to add data synchronously
    Player():sendCallback("onCosmicCodexGatherData")
end

-- API Function for other mods
function CosmicCodex.addCategory(id, title, iconPath)
    if self.categories[id] then return end
    local categoryIndex = self.tree:add(nil, title, "onEntrySelected", false, id)
    self.categories[id] = { index = categoryIndex, title = title, icon = iconPath }
    self.categoryCount = self.categoryCount + 1
end

function CosmicCodex.addArticle(categoryId, id, title, text, picturePath)
    local cat = self.categories[categoryId]
    if not cat then return end
    
    local searchText = string.lower(string.trim(self.searchTextBox.text))
    if searchText ~= "" then
        if not string.match(string.lower(title), searchText) and not string.match(string.lower(text), searchText) then
            return -- skip if filtered
        end
    end

    local articleIndex = self.tree:add(cat.index, title, "onEntrySelected", true, id)
    self.articles[articleIndex] = { title = title, text = text, picture = picturePath, categoryId = categoryId }
end

function addCategory(id, title, iconPath)
    CosmicCodex.addCategory(id, title, iconPath)
end

function addArticle(categoryId, id, title, text, picturePath)
    CosmicCodex.addArticle(categoryId, id, title, text, picturePath)
end

function CosmicCodex.onEntrySelected(index)
    self.tree.selectedIndex = index
    self.refreshUI()
end

function CosmicCodex.refreshUI()
    if self.tree.selectedIndex and self.articles[self.tree.selectedIndex] then
        local article = self.articles[self.tree.selectedIndex]
        self.titleLabel.caption = article.title or ""
        self.textField.text = article.text or ""
        if article.picture and article.picture ~= "" then
            self.picture.picture = article.picture
            self.picture.rect = Rect(self.originalRect.lower + self.tab.lower, self.originalRect.upper + self.tab.lower)
            self.picture:show()
        else
            self.picture:hide()
        end
        self.textField:show()
        self.backgroundBox:show()
    else
        self.titleLabel.caption = "Cosmic Codex"%_t
        self.picture.picture = "data/textures/ui/cosmiccodex_main.png"
        self.picture.rect = Rect(self.originalRect.lower + self.tab.lower, self.originalRect.upper + self.tab.lower)
        self.picture:fitIntoRect()
        self.picture:show()
        self.textField.text = "Welcome to the \\c(0d0)Cosmic Codex\\c()!\n\nThis is the central repository for all knowledge regarding the Cosmic Mod Series.\nSelect a category on the left to begin."%_t
        self.textField:show()
        self.backgroundBox:show()
    end
end

end -- onClient
