-- Client-only shared UI construction helpers for player-window tabs. Pure UI script:
-- guarded immediately below, per the standing rule for any script that builds UI with
-- %_t at module scope (see Avorion_Modding_Codex.md's "UI Development" section).
if onServer() then return end

include("cosmicvaultframework")

--[[
    Cosmic Vault UI Kit
    Shared, additive layout/table/status-color helpers for building player-window tabs
    in the visual style already established by Cosmic Overhaul's Command Center and
    Factory Overview tabs (two-row header, sortable column-button strip above a list,
    green/amber/red status coloring).

    Why this exists: three independent Cosmic Overhaul tab files each hand-computed the
    vertical clearance between a header control row and a sortable-column-button strip
    drawn just above a list, and each got the arithmetic wrong in a slightly different
    way (factory_overview_tab.lua, command_center_tab.lua, galacticpolitics_tab.lua all
    shipped the same overlap bug independently). CosmicVaultUIKit.createHeaderLayout
    owns that arithmetic once, so the bug class can't recur per-file.

    Requires the caller's script to be a normal client UI script (Tab/Window/ScrollFrame
    etc. all expose the same create*() surface this module calls into).
]]

-- namespace CosmicVaultUIKit
CosmicVaultUIKit = CosmicVaultUIKit or {}

-- ============================================================================
-- Status colors
-- ============================================================================

--- Canonical green/amber/red/gray palette. Factory Overview and Command Center had
-- already drifted from each other on the exact "red" (1.0,0.3,0.3 vs 1.0,0.4,0.4)
-- despite both intending "the same" status red -- this is the single source of truth
-- future callers should use instead of hand-picking their own ColorRGB literal.
CosmicVaultUIKit.STATUS_COLORS = {
    green = ColorRGB(0.2, 1.0, 0.2),
    amber = ColorRGB(1.0, 0.85, 0.2),
    red   = ColorRGB(1.0, 0.3, 0.3),
    gray  = ColorRGB(0.7, 0.7, 0.7),
}

--- Maps a percentage (0-100) to green/amber/red using configurable thresholds.
-- @param pct (number) the percentage value
-- @param opts (table|nil) { greenMin=80, amberMin=40, invert=false }
--   invert=true treats a HIGH percentage as bad (e.g. "% time spent in an error state")
--   instead of the default "high is good" (e.g. "% time spent Running").
-- @return (ColorRGB)
function CosmicVaultUIKit.statusColorForPercent(pct, opts)
    opts = opts or {}
    local greenMin = opts.greenMin or 80
    local amberMin = opts.amberMin or 40
    pct = tonumber(pct) or 0

    local effective = pct
    if opts.invert then effective = 100 - pct end

    if effective >= greenMin then return CosmicVaultUIKit.STATUS_COLORS.green end
    if effective >= amberMin then return CosmicVaultUIKit.STATUS_COLORS.amber end
    return CosmicVaultUIKit.STATUS_COLORS.red
end

--- Maps a keyword (a working-state reason, an operation status, etc.) to green/amber/red/gray.
-- @param keyword (string) the text to classify
-- @param classify (table|nil) optional exact-match table, e.g. { running="green", idle="gray" }
--   (lowercased keys). Falls back to the substring heuristic already used inline in
--   factory_overview_tab.lua/command_center_tab.lua ("run"->green, "idle"/"wait"->gray,
--   anything else -> red) when no exact match is found.
-- @return (ColorRGB)
function CosmicVaultUIKit.statusColorForKeyword(keyword, classify)
    local lower = string.lower(tostring(keyword or ""))

    if classify and classify[lower] then
        local mapped = CosmicVaultUIKit.STATUS_COLORS[classify[lower]]
        if mapped then return mapped end
    end

    if string.find(lower, "run") then return CosmicVaultUIKit.STATUS_COLORS.green end
    if string.find(lower, "idle") or string.find(lower, "wait") then return CosmicVaultUIKit.STATUS_COLORS.gray end
    return CosmicVaultUIKit.STATUS_COLORS.red
end

-- ============================================================================
-- Header layout
-- ============================================================================

--- Builds a stacked header block (a title/totals row, then N control rows) above a
-- content area, reserving vertical clearance for an optional sortable-column button
-- strip at the header block's own bottom edge. Callers never compute "topHeight - N"
-- by hand -- verified against the UIHorizontalSplitter API docs that its single
-- numeric `margin` constructor argument sets all four sides uniformly (there is no
-- bottom-only clearance parameter), which is the actual mechanism behind the header/
-- sort-strip overlap bug this function exists to prevent. This helper works around
-- that by setting a small uniform margin for the splitter's own inset, then adjusting
-- `marginBottom` specifically to the sort-strip's height (both properties confirmed to
-- exist independently on UIHorizontalSplitter) -- so left/right insets stay small while
-- only the bottom edge pays for the strip's clearance.
--
-- @param container (Tab|Window|ScrollFrame|UIContainer) anything exposing .size and createLabel/createButton/etc.
-- @param opts (table|nil) {
--     margin (number, default 10) -- uniform inset used for the splitter's left/right/top
--     headerHeightFraction (number, default 0.16) -- fraction of container height used for the whole header block
--     sortStripHeight (number, default 22) -- px reserved at the header block's bottom edge; 0 disables it
--     rows (table, default {{fraction=1.0}}) -- array of {fraction=<share of the header's own row space>},
--         fractions need not sum to 1.0 exactly; each row gets `fraction * rowAreaHeight`, stacked top-to-bottom
--     rowGap (number, default 4) -- px gap left between stacked rows
-- }
-- @return (table) {
--     rows = {Rect, ...},        -- one Rect per requested row, already clear of the sort strip
--     sortStripRect = Rect|nil,  -- nil if sortStripHeight == 0; spans the full header width at its bottom edge
--     contentRect = Rect,        -- everything below the header block -- feed to createSortableTable/createListBoxEx
--     width = number, margin = number, topHeight = number,
-- }
function CosmicVaultUIKit.createHeaderLayout(container, opts)
    opts = opts or {}
    local margin = opts.margin or 10
    local headerFraction = opts.headerHeightFraction or 0.16
    local sortStripHeight = opts.sortStripHeight
    if sortStripHeight == nil then sortStripHeight = 22 end
    local rows = opts.rows or { { fraction = 1.0 } }
    local rowGap = opts.rowGap or 4

    local hsplit = UIHorizontalSplitter(Rect(container.size), margin, margin, headerFraction)
    if sortStripHeight > 0 then
        -- Only the bottom edge needs to clear the sort-strip; left/right/top keep the
        -- small uniform margin so the header doesn't lose unrelated horizontal space.
        hsplit.marginBottom = sortStripHeight + margin
    end

    local top = hsplit.top
    local width = top.width
    local topHeight = top.height

    -- Row space is whatever's left inside the top rect after the splitter's own
    -- margin has already been applied (hsplit.top is the post-margin rect).
    local rowAreaHeight = topHeight
    local builtRows = {}
    local cursorY = 0
    for _, row in ipairs(rows) do
        local h = rowAreaHeight * (row.fraction or 1.0)
        table.insert(builtRows, Rect(0, cursorY, width, cursorY + h))
        cursorY = cursorY + h + rowGap
    end

    local sortStripRect = nil
    if sortStripHeight > 0 then
        sortStripRect = Rect(0, topHeight, width, topHeight + sortStripHeight)
    end

    return {
        rows = builtRows,
        sortStripRect = sortStripRect,
        contentRect = hsplit.bottom,
        width = width,
        margin = margin,
        topHeight = topHeight,
    }
end

-- ============================================================================
-- Sortable table
-- ============================================================================

-- IMPORTANT resolution rule, verified against factory_overview_tab.lua (its Tab's
-- onSelectedFunction="clientFetchDataFromGalaxy" resolves to FactoryOverview.
-- clientFetchDataFromGalaxy, not any global or included-library function): Avorion
-- resolves a UI element's string callback name against the CALLING script's OWN
-- namespace table, never against a shared library's namespace. That means
-- CosmicVaultUIKit cannot register its own dispatcher functions and hand back a name
-- for an arbitrary caller's button/list to invoke -- the engine would look for that
-- name on the CALLER's namespace table and never find it. createSortableTable
-- therefore takes the caller's own namespace table as its first argument and installs
-- small per-instance dispatcher functions directly onto it, using generated names
-- unique per table instance so multiple sortable tables in the same script (or
-- multiple Cosmic mods each calling this) never collide.
local _instanceCounter = 0

local TableHandle = {}
TableHandle.__index = TableHandle

function TableHandle:_resortBy(columnIndex)
    if self.selectedSortColumn == columnIndex then
        self.sortDirection = self.sortDirection * -1
    else
        self.selectedSortColumn = columnIndex
        self.sortDirection = 1
    end
    self:_updateSortIcons()
    self:_repopulate()
end

function TableHandle:_updateSortIcons()
    for i, button in ipairs(self.sortButtons) do
        if i == self.selectedSortColumn then
            button.icon = (self.sortDirection < 0) and "data/textures/icons/arrow-down2.png" or "data/textures/icons/arrow-up2.png"
        else
            button.icon = ""
        end
    end
end

function TableHandle:_repopulate()
    local columns = self.columns
    local sortCol = columns[self.selectedSortColumn]
    local rows = self.rowData

    if sortCol and sortCol.sortValue then
        local dir = self.sortDirection
        table.sort(rows, function(a, b)
            local av, bv = sortCol.sortValue(a), sortCol.sortValue(b)
            if dir < 0 then return av > bv end
            return av < bv
        end)
    end

    self.list:clear()
    self.list:addRow() -- headline: no value, matching every existing list's own header row
    for i, col in ipairs(columns) do
        self.list:setEntryNoCallback(i - 1, 0, col.label, true, false, ColorRGB(1, 1, 1))
    end

    -- addRow's first argument is the row's associated "value" (what .selectedValue
    -- returns for whichever row is clicked) -- confirmed against three working
    -- examples in this codebase (factory_overview_tab.lua, cc_newsboard.lua,
    -- galacticpolitics_tab.lua), since neither the ListBoxEx stub nor the raw HTML
    -- docs document this parameter at all (both show addRow() as taking zero
    -- arguments, which is simply wrong for this API). Every real example passes a
    -- string, never a table, so this follows galacticpolitics_tab.lua's exact
    -- convention: pass tostring(i) (the row's position in this already-sorted
    -- `rows` array) and keep our own i -> rowData lookup, rather than risk passing
    -- an unverified raw table value into a native widget property.
    self.rowsByValue = {}
    for i, rowData in ipairs(rows) do
        self.list:addRow(tostring(i))
        local listRow = self.list.rows - 1
        for colIdx, col in ipairs(columns) do
            local text = col.cellText and col.cellText(rowData) or ""
            local color = col.cellColor and col.cellColor(rowData) or ColorRGB(0.8, 0.8, 0.8)
            self.list:setEntryNoCallback(colIdx - 1, listRow, text, false, false, color)
        end
        self.rowsByValue[tostring(i)] = rowData
    end
end

--- Replaces the table's row data, re-sorts by whatever column is currently selected,
-- and repopulates the ListBoxEx.
function TableHandle:setRows(rowDataArray)
    self.rowData = rowDataArray or {}
    self:_repopulate()
end

--- Registers a callback fired with the selected row's original data whenever a row is
-- clicked (wired through ListBoxEx.onSelectFunction).
function TableHandle:setSelectionChangedHandler(fn)
    self.onRowSelected = fn
end

function TableHandle:getSelectedRow()
    if not self.list.selectedValue then return nil end
    return self.rowsByValue[self.list.selectedValue]
end

function TableHandle:_onListSelected(list)
    if self.onRowSelected then
        self.onRowSelected(self:getSelectedRow())
    end
end

--- Builds a sortable, scrollable table: a row of per-column sort buttons (placed in
-- `sortStripRect`, typically the one returned by createHeaderLayout) plus a backing
-- ListBoxEx. Adding or removing a column means editing the `columns` array in one
-- place instead of touching button rects, ListBoxEx column widths, and a numbered
-- sort-callback function separately.
--
-- @param namespaceTable (table) the CALLING script's own namespace table (e.g. the
--     `FactoryOverview`/`CommandCenter` table your own script is declared as). Required
--     because the engine resolves button/list callback strings against this exact
--     table for a namespaced script -- see the resolution-rule note above.
-- @param container (Tab|Window|ScrollFrame) must expose createButton/createListBoxEx
-- @param rect (Rect) the ListBoxEx's own rect (i.e. layout.contentRect)
-- @param columns (table) array of {
--     label (string),
--     width (number) -- proportional weight (same convention as CosmicUIVerticalProportionalSplitter)
--     sortValue (function(rowData) -> comparable) -- nil = column is not sortable
--     cellText (function(rowData) -> string),
--     cellColor (function(rowData) -> ColorRGB|nil),
-- }
-- @param opts (table|nil) {
--     sortStripRect (Rect|nil) -- if given, builds the sort-button strip here (usually layout.sortStripRect)
--     rowHeight (number, default 32)
--     defaultSortColumn (number, default 1)
--     defaultSortDirection (number, default 1)
-- }
-- @return (table) TableHandle -- see setRows/setSelectionChangedHandler/getSelectedRow above; .list is the raw ListBoxEx
function CosmicVaultUIKit.createSortableTable(namespaceTable, container, rect, columns, opts)
    opts = opts or {}
    _instanceCounter = _instanceCounter + 1
    local prefix = "_cvuikit" .. _instanceCounter .. "_"

    local handle = setmetatable({}, TableHandle)
    handle.columns = columns
    handle.rowData = {}
    handle.rowsByValue = {} -- safe default if getSelectedRow() is ever called before the first setRows()
    handle.selectedSortColumn = opts.defaultSortColumn or 1
    handle.sortDirection = opts.defaultSortDirection or 1
    handle.sortButtons = {}

    local list = container:createListBoxEx(rect)
    list.columns = #columns
    list.rowHeight = opts.rowHeight or 32
    list.headline = true

    local selectFnName = prefix .. "onSelect"
    namespaceTable[selectFnName] = function(l) handle:_onListSelected(l) end
    list.onSelectFunction = selectFnName
    handle.list = list

    -- Column widths: reuse the proportional splitter's convention (weight vs. fixed px)
    -- rather than reimplementing width math -- values < 1 are treated as proportional
    -- weight shares of the available width here, matching how callers already think
    -- about column widths elsewhere in the codebase.
    local totalWeight = 0
    for _, col in ipairs(columns) do totalWeight = totalWeight + (col.width or 1) end
    local availableWidth = rect.width - 20 -- leaves room for the scrollbar, matching existing tabs' convention
    for i, col in ipairs(columns) do
        list:setColumnWidth(i - 1, availableWidth * ((col.width or 1) / totalWeight))
    end

    if opts.sortStripRect then
        local strip = opts.sortStripRect
        local colWidth = strip.width / #columns
        for i, col in ipairs(columns) do
            local btnRect = Rect(strip.lower.x + (i - 1) * colWidth + 2, strip.lower.y, strip.lower.x + i * colWidth - 3, strip.upper.y)
            if col.sortValue then
                local fnName = prefix .. "sort" .. i
                namespaceTable[fnName] = function(button) handle:_resortBy(i) end
                local button = container:createButton(btnRect, "", fnName)
                button.tooltip = "Sort by "%_t .. col.label
                table.insert(handle.sortButtons, button)
            else
                local button = container:createButton(btnRect, "", "")
                button.active = false
                table.insert(handle.sortButtons, button)
            end
        end
        handle:_updateSortIcons()
    end

    return handle
end

if CosmicVaultFramework and CosmicVaultFramework.registerModule then
    CosmicVaultFramework.registerModule("CosmicVaultUIKit", {version = "1.0.0"})
end

return CosmicVaultUIKit
