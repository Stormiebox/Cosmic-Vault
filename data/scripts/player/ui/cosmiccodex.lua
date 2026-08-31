
include("stringutility")
include("utility")
include("callable")

-- namespace CosmicCodex
CosmicCodex = {}
local self = CosmicCodex

if onClient() then

self.categories = {}
self.chapters = {}
self.articles = {}
self.categoryCount = 0

self.tab = nil
self.tree = nil
self.titleLabel = nil
self.picture = nil
self.textField = nil
self.originalRect = nil
self.textRectOriginal = nil
self.fullTextRect = nil

function CosmicCodex.initialize()
    Player():registerCallback("onPostRenderHud", "onPostRenderHud")
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
    self.titleLabel.centered = true

    self.originalRect = hsplit2.top
    self.picture = self.tab:createPicture(self.originalRect, "")
    self.picture.isIcon = false -- Prevents it from coloring black like icons

    self.textRectOriginal = textRect
    self.fullTextRect = hsplit.bottom

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
    self.tree:setLevelStyle(1, 25, 16)
    self.categories = {}
    self.chapters = {}
    self.articles = {}
    self.categoryCount = 0

    self.refreshUI()

    -- Trigger other scripts to add data synchronously
    Player():sendCallback("onCosmicCodexGatherData")
end

-- API Function for other mods
function CosmicCodex.addCategory(id, title, iconPath)
    if not id then return end
    if type(title) ~= "string" then title = tostring(title) or "" end
    if self.categories[id] then return end
    local categoryIndex = self.tree:add(nil, title, "onEntrySelected", false, id)
    self.categories[id] = { index = categoryIndex, title = title, icon = iconPath }
    self.categoryCount = self.categoryCount + 1
end

function CosmicCodex.addChapter(categoryId, id, title)
    if not categoryId or not id then return end
    if type(title) ~= "string" then title = tostring(title) or "" end
    local cat = self.categories[categoryId]
    if not cat then return end
    if self.chapters[id] then return end
    local chapterIndex = self.tree:add(cat.index, title, "onEntrySelected", false, id)
    self.chapters[id] = { index = chapterIndex, title = title, categoryId = categoryId }
end

function CosmicCodex.addArticle(chapterId, id, title, text, picturePath)
    if not chapterId or not id then return end
    if type(title) ~= "string" then title = tostring(title) or "" end
    if type(text) ~= "string" then text = tostring(text) or "" end

    local chapter = self.chapters[chapterId]
    -- Fallback for backwards compatibility
    if not chapter then chapter = self.categories[chapterId] end
    if not chapter then return end

    local searchText = string.lower(string.trim(self.searchTextBox.text or ""))
    if searchText ~= "" then
        -- string.find with arg 4 = true disables pattern matching, preventing crashes from special chars
        if not string.find(string.lower(title), searchText, 1, true) and not string.find(string.lower(text), searchText, 1, true) then
            return -- skip if filtered
        end
    end

    local articleIndex = self.tree:add(chapter.index, title, "onEntrySelected", true, id)
    self.articles[articleIndex] = { title = title, text = text, picture = picturePath, chapterId = chapterId }
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
            self.textField.rect = Rect(self.textRectOriginal.lower + self.tab.lower, self.textRectOriginal.upper + self.tab.lower)
            self.backgroundBox.rect = self.textField.rect
        else
            self.picture:hide()
            self.textField.rect = Rect(self.fullTextRect.lower + self.tab.lower, self.fullTextRect.upper + self.tab.lower)
            self.backgroundBox.rect = self.textField.rect
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
        self.textField.rect = Rect(self.textRectOriginal.lower + self.tab.lower, self.textRectOriginal.upper + self.tab.lower)
        self.backgroundBox.rect = self.textField.rect
        self.textField:show()
        self.backgroundBox:show()
    end
end

function CosmicCodex.onPostRenderHud(state, timeStep)
    local ccm = include("ccm")
    if ccm then
        local cvcfg = ccm.bind("CosmicVault")
        if cvcfg.isKeyComboDown("hotkeyCodex") then
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
end

end -- onClient

return CosmicCodex
