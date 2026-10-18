-- The window: the best items per slot for a specialization, where each drops, and the filters.
local ADDON, ns = ...

local L = ns.L
local UI = {}
ns.UI = UI

local Skin = ns.Skin
local C = Skin.C

local WIDTH, HEIGHT = 900, 610
local ROW_HEIGHT, LIST_TOP, LIST_WIDTH = 32, -112, 572
local ALT_ROWS = 7
local DETAIL_X = LIST_WIDTH + 28

local GROUP_CHOICES = {
    { value = "dungeon", label = "Dungeon players" },
    { value = "all", label = "All top players" },
}
local SLOT_NAMES = {
    head = "Head", neck = "Neck", shoulder = "Shoulders", back = "Back", chest = "Chest",
    wrist = "Wrists", hands = "Hands", waist = "Waist", legs = "Legs", feet = "Feet",
    finger = "Rings", trinket = "Trinkets", main_hand = "Main hand", off_hand = "Off hand",
}
ns.SLOT_NAMES = SLOT_NAMES

local frame, rows, alternatives, widgets = nil, {}, {}, {}
local page = "items"
local registered = {}
local PAGE_ORDER = { "items", "stats", "gear", "talents", "players", "farming" }
local PAGE_LABELS = { items = "Items", stats = "Stats", gear = "Gear", talents = "Talents", players = "Players",
    farming = "Farming" }
local stat = { main = {}, minor = {} }
local shownKey, bisSet = nil, {}
local TRACK_NAMES = { veteran = "Veteran", champion = "Champion", hero = "Hero", myth = "Myth" }
local TIER_TEXT = { strong = "Good", option = "Decent" }
local TIER_COLOR = { strong = "ffa335ee", option = "ffffffff" }
local BIS_COLOR = "ffffd100"
local BAR_WIDTH = 64
local SHARE_WIDTH = 84
local MARK_STYLE = {
    must = { text = "Important", color = "ffff8c1a" },
    nice = { text = "Interesting", color = "ff52b7a8" },
}
local selectedSlot = nil
local pending = false

-- ------------------------------------------------------------------ item info

local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local getItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

local function refreshSoon()
    if pending then return end
    pending = true
    local function run()
        pending = false
        UI.Refresh()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, run) else run() end
end

--- Name and quality of an item; nil until the client has loaded it (a refresh follows).
local function itemNameOf(id)
    local name, _, quality = getItemInfo(id)
    if name then return name, quality end
    if Item and Item.CreateFromItemID then
        Item:CreateFromItemID(id):ContinueOnItemLoad(refreshSoon)
    end
    return nil
end

local function colorFor(quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 4]
    if color then return color.r, color.g, color.b end
    return 0.64, 0.21, 0.93
end

local function showItemTooltip(owner, id)
    if not (GameTooltip and id) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local db = ns.Settings()
    local lo = ns.DungeonLevel(id, db.content, db.keyLevel, db.vault)
    local link = lo and ns.LinkAtLevel(id, lo)
    if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetItemByID(id) end
    if ns.KeyTable(id) then
        for _, vault in ipairs({ false, true }) do
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(vault and L["Great Vault"] or L["End of the dungeon"], 1, 0.82, 0)
            for _, group in ipairs(ns.KeyGroups(vault)) do
                GameTooltip:AddDoubleLine(group.label, group.ilvl .. " " .. L[TRACK_NAMES[group.track]] .. " " .. group.rank
                    .. "/" .. ns.TRACK_RANKS, 0.8, 0.8, 0.8, 0.64, 0.21, 0.93)
            end
        end
    end
    if owner.holdText then GameTooltip:AddLine(owner.holdText, 1, 1, 1) end
    GameTooltip:AddLine(L["Right-click marks the item."], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function hideTooltip() if GameTooltip then GameTooltip:Hide() end end

--- Where an item comes from, as the shown list names it: the dungeon list names dungeons, the raid list bosses of
--- the raid, Overall the most specific source. Pieces without an instance (Catalyst, crafted) name their kind.
local function sourceText(id)
    local content = ns.Settings().content
    local only = content == "raid" and "raid" or (content == "mplus" and "dungeon" or nil)
    local best, more = ns.BestDrop(id, only)
    if not best then return L["Other source"] end
    local text = best.instance == 0 and L[best.instanceName] or ns.SourceLabel(id, only)
    if more > 0 then text = text .. " (+" .. more .. ")" end
    return text
end

-- ------------------------------------------------------------------ small widgets

local function makeText(parent, template)
    return Skin.Text(parent, template)
end

local function makeCheck(parent, label, onClick)
    return Skin.Toggle(parent, label, onClick)
end

--- A choice from a list: a dropdown button; a click cycles when the game's menu system is missing.
local function makeChoice(parent, width, options, get, set)
    return Skin.Dropdown(parent, width, function(root)
        for _, option in ipairs(options) do
            root:CreateRadio(L[option.label], function() return get() == option.value end,
                function() set(option.value) end)
        end
    end, function()
        local at = 1
        for index, option in ipairs(options) do if option.value == get() then at = index end end
        set(options[at % #options + 1].value)
    end)
end

-- ------------------------------------------------------------------ the window

local function specChoices()
    local list = {}
    for _, spec in ipairs(ns.SpecList()) do list[#list + 1] = { value = spec.id, label = spec.label } end
    return list
end

local function buildSpecPicker(parent)
    local choices = specChoices()
    table.insert(choices, 1, { value = nil, label = "(you)" })
    return Skin.Dropdown(parent, 230, function(root)
        root:CreateRadio(L["Specialization"] .. ": (you)", function() return ns.Settings().spec == nil end,
            function() ns.Settings().spec = nil; UI.Refresh() end)
        local byClass = {}
        for _, spec in ipairs(ns.SpecList()) do
            local menu = byClass[spec.class]
            if not menu then
                menu = root:CreateButton(ns.Title(spec.class))
                byClass[spec.class] = menu
            end
            menu:CreateRadio(ns.Title(spec.spec), function() return ns.Settings().spec == spec.id end,
                function() ns.Settings().spec = spec.id; UI.Refresh() end)
        end
        -- a second specialization: the lists then show only the items both of them want
        local compare = root:CreateButton(L["Compare with"])
        compare:CreateRadio(L["(none)"], function() return ns.Settings().compare == nil end,
            function() ns.Settings().compare = nil; UI.Refresh() end)
        local compareClass = {}
        for _, spec in ipairs(ns.SpecList()) do
            local menu = compareClass[spec.class]
            if not menu then
                menu = compare:CreateButton(ns.Title(spec.class))
                compareClass[spec.class] = menu
            end
            menu:CreateRadio(ns.Title(spec.spec), function() return ns.Settings().compare == spec.id end,
                function() ns.Settings().compare = spec.id; UI.Refresh() end)
        end
    end, function()
        local at = 1
        for index, option in ipairs(choices) do if option.value == ns.Settings().spec then at = index end end
        ns.Settings().spec = choices[at % #choices + 1].value
        UI.Refresh()
    end)
end

--- The thin bar under the player count: how large a share of the top players wear the item.
--- row.bar:SetValue(share, color) sets it; row.barBack and row.barFill stay reachable for tests.
local function addBar(row, right, down)
    row.bar = Skin.Bar(row, BAR_WIDTH, 3)
    row.bar.back:SetPoint("RIGHT", row, "RIGHT", right, down)
    row.barBack, row.barFill = row.bar.back, row.bar.fill
end

local function hexColor(color)
    return tonumber(color:sub(3, 4), 16) / 255, tonumber(color:sub(5, 6), 16) / 255, tonumber(color:sub(7, 8), 16) / 255
end

-- The color of the n-th stat of a ranking: gold, purple, then white.
local RANK_COLORS = { "ffffd100", "ffa335ee", "ffffffff", "ffffffff" }

--- One line of the stats page: name, bar, value.
local function buildStatRow(parent, top)
    local row = {}
    row.name = makeText(parent, "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, top)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")
    row.back = parent:CreateTexture(nil, "ARTWORK")
    row.back:SetSize(400, 10)
    row.back:SetPoint("TOPLEFT", parent, "TOPLEFT", 180, top - 3)
    row.back:SetColorTexture(1, 1, 1, 0.1)
    row.fill = parent:CreateTexture(nil, "OVERLAY")
    row.fill:SetSize(400, 10)
    row.fill:SetPoint("LEFT", row.back, "LEFT", 0, 0)
    row.value = makeText(parent, "GameFontHighlight")
    row.value:SetPoint("TOPLEFT", parent, "TOPLEFT", 596, top)
    row.value:SetWidth(210)
    row.value:SetJustifyH("LEFT")
    return row
end

local function showStatRows(rowsOut, ranking)
    local top = 0
    for _, item in ipairs(ranking) do if item.rating > top then top = item.rating end end
    for index, row in ipairs(rowsOut) do
        local item = ranking[index]
        local color = RANK_COLORS[index] or "ffffffff"
        local r, g, b = hexColor(color)
        row.name:SetText("|c" .. color .. L[item.name] .. "|r")
        row.fill:SetColorTexture(r, g, b, 1)
        row.fill:SetWidth(top > 0 and math.max(2, 400 * item.rating / top) or 2)
        row.value:SetText("|c" .. color .. "+" .. item.rating .. "|r   |cff999999" .. string.format("%.1f%%", item.percent) .. "|r")
    end
end

local function rankingText(ranking)
    local parts = {}
    for index, item in ipairs(ranking) do
        parts[index] = "|c" .. (RANK_COLORS[index] or "ffffffff") .. L[item.name]:upper() .. "|r"
    end
    return table.concat(parts, "  >  ")
end

local function buildStatsPanel(parent)
    stat.mainTitle = makeText(parent, "GameFontNormalLarge")
    stat.mainTitle:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -112)
    stat.mainTitle:SetText(L["Optimal secondary stats"])
    for index = 1, #ns.MAIN_STATS do stat.main[index] = buildStatRow(parent, -146 - (index - 1) * 34) end
    stat.mainRank = makeText(parent, "GameFontHighlight")
    stat.mainRank:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -146 - #ns.MAIN_STATS * 34 - 4)
    stat.minorTitle = makeText(parent, "GameFontNormalLarge")
    stat.minorTitle:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -330)
    stat.minorTitle:SetText(L["Additional minor stats"])
    for index = 1, #ns.MINOR_STATS do stat.minor[index] = buildStatRow(parent, -364 - (index - 1) * 34) end
    stat.minorRank = makeText(parent, "GameFontHighlight")
    stat.minorRank:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -364 - #ns.MINOR_STATS * 34 - 4)
    stat.empty = makeText(parent, "GameFontDisable")
    stat.empty:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -124)
    stat.empty:SetText(L["No stats for this specialization yet."])
end

--- Shows the page that is up and fills it; the item list and its detail column give way to every page but "items".
local function refreshPages(class, spec)
    local statsOn = page == "stats"
    local group = ns.Settings().group
    local data = class and ns.StatsOf(class, spec, group)
    local parts = { stat.mainTitle, stat.mainRank, stat.minorTitle, stat.minorRank }
    for _, list in ipairs({ stat.main, stat.minor }) do
        for _, row in ipairs(list) do
            parts[#parts + 1] = row.name; parts[#parts + 1] = row.back; parts[#parts + 1] = row.fill; parts[#parts + 1] = row.value
        end
    end
    for _, part in ipairs(parts) do part:SetShown(statsOn and data ~= nil) end
    stat.empty:SetShown(statsOn and data == nil)
    widgets.note:SetText("")
    for _, part in ipairs(widgets.itemsOnly) do part:SetShown(page == "items") end
    if page ~= "items" then
        for _, row in ipairs(rows) do row:Hide() end
        for _, row in ipairs(alternatives) do row:Hide() end
        widgets.detailTitle:Hide(); widgets.detailSub:Hide(); widgets.altHeader:Hide(); widgets.guide:Hide()
        widgets.message:SetText("")
    else
        for _, row in ipairs(rows) do row:Show() end
        widgets.detailTitle:Show(); widgets.detailSub:Show()
    end
    if statsOn and data then
        local main = ns.StatRanking(data, ns.MAIN_STATS)
        local minor = ns.StatRanking(data, ns.MINOR_STATS)
        showStatRows(stat.main, main)
        showStatRows(stat.minor, minor)
        stat.mainRank:SetText(rankingText(main))
        stat.minorRank:SetText(rankingText(minor))
        widgets.note:SetText(string.format(L["Average of the %d top players"], data.n or 0))
    end
    for name, def in pairs(registered) do
        if page == name then
            widgets.note:SetText(def.refresh(class, spec, group) or "")
        else
            for _, part in ipairs(def.parts or {}) do part:Hide() end
        end
    end
    for _, name in ipairs(PAGE_ORDER) do
        local button = widgets.pageButtons and widgets.pageButtons[name]
        if button then
            button:SetActive(page == name)
        end
    end
end

--- Pages next to the item list register here (Pages.lua): def.build(frame) returns the parts to hide,
--- def.refresh(class, spec, group) fills them and may return a note for the foot of the window.
function UI.RegisterPage(name, def)
    registered[name] = def
end

local function wireClicks(row, onSelect)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.itemId and shownKey then ns.CycleMark(shownKey, self.itemId); UI.Refresh() end
            return
        end
        if self.itemId and IsModifiedClick and IsModifiedClick("CHATLINK") then
            local _, link = getItemInfo(self.itemId)
            if link and HandleModifiedItemClick then HandleModifiedItemClick(link) return end
        end
        if onSelect then onSelect(self) end
    end)
end

local function cropIcon(texture)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function buildRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, LIST_TOP - (index - 1) * (ROW_HEIGHT + 2))
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.05)
    row.highlight:Hide()
    local fill = row:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.12)
    local mark = row:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 0, 0)
    mark:SetPoint("BOTTOMLEFT", 0, 0)
    mark:SetWidth(2)
    mark:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    row.selected = {
        Show = function() fill:Show(); mark:Show() end,
        Hide = function() fill:Hide(); mark:Hide() end,
    }
    row.selected.Hide()
    row.slot = Skin.Text(row, "GameFontNormalSmall", 11)
    row.slot:SetPoint("LEFT", 12, 0)
    row.slot:SetWidth(64)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", 82, 0)
    cropIcon(row.icon)
    row.name = Skin.Text(row, "GameFontHighlight", 13)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 6)
    row.name:SetWidth(318)
    row.where = Skin.Text(row, "GameFontDisableSmall", 11)
    row.where:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.where:SetWidth(318)
    row.share = Skin.Text(row, "GameFontHighlight", 12)
    row.share:SetPoint("RIGHT", -10, 6)
    row.share:SetWidth(SHARE_WIDTH)
    row.share:SetJustifyH("RIGHT")
    addBar(row, -10, -8)
    -- the next best item of the slot, small, so the alternative is seen without a click
    row.alt = CreateFrame("Button", nil, row)
    row.alt:SetSize(22, 22)
    row.alt:SetPoint("RIGHT", row, "RIGHT", -(SHARE_WIDTH + 24), 0)
    row.alt.icon = row.alt:CreateTexture(nil, "ARTWORK")
    row.alt.icon:SetAllPoints()
    cropIcon(row.alt.icon)
    row.alt:SetScript("OnEnter", function(self) showItemTooltip(self, self.itemId) end)
    row.alt:SetScript("OnLeave", hideTooltip)
    row.alt:SetScript("OnClick", function(self)
        if self.itemId and IsModifiedClick and IsModifiedClick("CHATLINK") then
            local _, link = getItemInfo(self.itemId)
            if link and HandleModifiedItemClick then HandleModifiedItemClick(link) return end
        end
        selectedSlot = row.slotKey
        UI.Refresh()
    end)
    row.alt:Hide()
    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        showItemTooltip(self, self.itemId)
    end)
    row:SetScript("OnLeave", function(self) self.highlight:Hide(); hideTooltip() end)
    wireClicks(row, function(self) selectedSlot = self.slotKey; UI.Refresh() end)
    return row
end

local function buildAlternative(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(WIDTH - DETAIL_X - 18, 42)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", DETAIL_X, -190 - (index - 1) * 46)
    Skin.Box(row, C.panel, C.border)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 8, 0)
    cropIcon(row.icon)
    row.name = Skin.Text(row, "GameFontHighlight", 12)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetWidth(150)
    row.where = Skin.Text(row, "GameFontDisableSmall", 11)
    row.where:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.where:SetWidth(150)
    row.share = Skin.Text(row, "GameFontHighlight", 12)
    row.share:SetPoint("RIGHT", -8, 6)
    row.share:SetWidth(SHARE_WIDTH)
    row.share:SetJustifyH("RIGHT")
    addBar(row, -8, -9)
    row:SetScript("OnEnter", function(self) showItemTooltip(self, self.itemId) end)
    row:SetScript("OnLeave", hideTooltip)
    wireClicks(row, nil)
    return row
end

--- Opens the Adventure Guide on the boss that drops an item (the first dungeon or raid source).
local function openInGuide(item)
    for _, drop in ipairs(ns.DropsOf(item)) do
        if (drop.kind == "dungeon" or drop.kind == "raid") and drop.instance ~= 0 then
            if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal") end
            if EncounterJournal_OpenJournal then
                pcall(EncounterJournal_OpenJournal, nil, drop.instance, drop.encounter, nil, nil, item)
            end
            return
        end
    end
end

local function rule(parent, x, y, width, height)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    line:SetSize(width, height)
    line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    return line
end

local function build()
    frame = CreateFrame("Frame", "KeyLootMasterFrame", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    Skin.Box(frame, C.window, C.borderStrong)
    if UISpecialFrames then table.insert(UISpecialFrames, "KeyLootMasterFrame") end

    -- header: logo, title, the pages as tabs, close
    local band = frame:CreateTexture(nil, "BORDER")
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("TOPRIGHT", -1, -1)
    band:SetHeight(49)
    band:SetColorTexture(C.header[1], C.header[2], C.header[3], 1)
    rule(frame, 1, -50, WIDTH - 2, 1)
    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(22, 22)
    logo:SetPoint("TOPLEFT", 16, -14)
    logo:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    local mark = Skin.Text(frame, "GameFontHighlight", 13, C.ink)
    mark:SetPoint("CENTER", logo, "CENTER", 0, 0)
    mark:SetText("K")
    local title = Skin.Text(frame, "GameFontHighlight", 14)
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetText("KeyLootMaster")

    widgets.pageButtons = {}
    for index, name in ipairs(PAGE_ORDER) do
        local tab = Skin.Tab(frame, L[PAGE_LABELS[name]], 80, 49)
        tab:SetPoint("TOPLEFT", 200 + (index - 1) * 84, -1)
        tab:SetScript("OnClick", function() page = name; UI.Refresh() end)
        widgets.pageButtons[name] = tab
    end
    widgets.stamp = Skin.Text(frame, "GameFontDisableSmall", 11)
    widgets.stamp:SetPoint("TOPRIGHT", -56, -20)
    widgets.stamp:SetJustifyH("RIGHT")
    local close = Skin.Button(frame, "x", 26, 26, "soft")
    close:SetPoint("TOPRIGHT", -14, -12)
    close:SetScript("OnClick", function() frame:Hide() end)

    -- toolbar: specialization, Mythic+ or raid, key level, vault, player group
    widgets.spec, widgets.setSpecText = buildSpecPicker(frame)
    widgets.spec:SetPoint("TOPLEFT", 16, -62)

    widgets.overall = Skin.Button(frame, L["Overall"], 66, 28, "ghost")
    widgets.overall:SetPoint("LEFT", widgets.spec, "RIGHT", 14, 0)
    widgets.overall:SetScript("OnClick", function() ns.Settings().content = "overall"; UI.Refresh() end)
    widgets.mplus = Skin.Button(frame, L["Mythic+"], 80, 28, "ghost")
    widgets.mplus:SetPoint("LEFT", widgets.overall, "RIGHT", 4, 0)
    widgets.mplus:SetScript("OnClick", function() ns.Settings().content = "mplus"; UI.Refresh() end)
    widgets.raid = Skin.Button(frame, L["Raid"], 60, 28, "ghost")
    widgets.raid:SetPoint("LEFT", widgets.mplus, "RIGHT", 4, 0)
    widgets.raid:SetScript("OnClick", function() ns.Settings().content = "raid"; UI.Refresh() end)

    local keyChoices = {}
    for _, level in ipairs(ns.KEY_LEVELS) do keyChoices[#keyChoices + 1] = { value = level, label = ns.KeyLabel(level) } end
    widgets.key, widgets.setKeyText = makeChoice(frame, 120, keyChoices,
        function() return ns.Settings().keyLevel end,
        function(value) ns.Settings().keyLevel = value; UI.Refresh() end)
    widgets.key:SetPoint("LEFT", widgets.raid, "RIGHT", 14, 0)
    widgets.vault = makeCheck(frame, L["Great Vault"], function(on) ns.Settings().vault = on; UI.Refresh() end)
    widgets.vault:SetPoint("LEFT", widgets.key, "RIGHT", 14, 0)
    widgets.group, widgets.setGroupText = makeChoice(frame, 150, GROUP_CHOICES,
        function() return ns.Settings().group end,
        function(value) ns.Settings().group = value; UI.Refresh() end)
    widgets.group:SetPoint("TOPRIGHT", -16, -62)

    -- the items page only: a line under the toolbar and one between the list and the detail column
    widgets.itemsOnly = {}
    local function itemsOnly(part) widgets.itemsOnly[#widgets.itemsOnly + 1] = part; return part end
    itemsOnly(rule(frame, 1, -100, WIDTH - 2, 1))
    itemsOnly(rule(frame, LIST_WIDTH + 18, -101, 1, HEIGHT - 102))

    for index = 1, #ns.SLOT_ORDER do rows[index] = buildRow(frame, index) end

    widgets.detailTitle = Skin.Text(frame, "GameFontNormalLarge", 20)
    widgets.detailTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", DETAIL_X, -116)
    widgets.detailSub = Skin.Text(frame, "GameFontDisableSmall", 11)
    widgets.detailSub:SetPoint("TOPLEFT", widgets.detailTitle, "BOTTOMLEFT", 0, -6)
    widgets.detailSub:SetWidth(WIDTH - DETAIL_X - 18)
    widgets.altHeader = Skin.Text(frame, "GameFontNormalSmall", 11)
    widgets.altHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", DETAIL_X, -166)
    widgets.altHeader:SetText(L["Alternatives"])
    for index = 1, ALT_ROWS do alternatives[index] = buildAlternative(frame, index) end

    widgets.guide = Skin.Button(frame, L["Open the Adventure Guide"], WIDTH - DETAIL_X - 18, 34, "chip")
    widgets.guide:SetPoint("BOTTOMRIGHT", -18, 18)
    widgets.guide:SetActive(true)
    widgets.guide:SetScript("OnClick", function(self) if self.itemId then openInGuide(self.itemId) end end)

    widgets.message = Skin.Text(frame, "GameFontDisable", 13)
    widgets.message:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, LIST_TOP - 12)
    widgets.message:SetWidth(LIST_WIDTH - 20)

    buildStatsPanel(frame)
    widgets.note = Skin.Text(frame, "GameFontDisableSmall", 11)
    widgets.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 16)
    for _, def in pairs(registered) do def.parts = def.build(frame) end
end

-- ------------------------------------------------------------------ refresh

--- "42 of 50 top players (84%)": how many of the players of the shown group wear the item.
local function holdTextOf(entry)
    local db = ns.Settings()
    local format = (db.content == "mplus" and db.group == "dungeon") and L["%d of %d dungeon players (%s)"]
        or L["%d of %d top players (%s)"]
    return string.format(format, math.floor(entry.share * entry.sample + 0.5), entry.sample, ns.Percent(entry.share))
end

--- "292 Champion  +13" for an item that drops at a key level; the difference to what is worn.
local function levelText(id, slotKey)
    local db = ns.Settings()
    local ilvl, track, rank = ns.DungeonLevel(id, db.content, db.keyLevel, db.vault)
    if not ilvl then return nil end
    local text = "|cffa335ee" .. ilvl .. " " .. L[TRACK_NAMES[track]] .. " " .. rank .. "/" .. ns.TRACK_RANKS .. "|r"
    local have = ns.WornItemLevel(slotKey)
    if have > 0 then
        local diff = ilvl - have
        if diff > 0 then text = text .. "  |cff52e052+" .. diff .. "|r"
        elseif diff < 0 then text = text .. "  |cffe05252" .. diff .. "|r"
        else text = text .. "  |cff999999=|r" end
    end
    return text
end

--- The BiS or tier tag and the player's own mark behind an item name.
local function tagsOf(id, share)
    local text = ""
    if bisSet[id] then
        text = text .. "  |cffffd100[" .. L["BiS"] .. "]|r"
    else
        local tier = share and ns.TierOf(share)
        if tier then text = text .. "  |c" .. TIER_COLOR[tier] .. "[" .. L[TIER_TEXT[tier]] .. "]|r" end
    end
    local mark = shownKey and ns.MarkOf(shownKey, id)
    local style = mark and MARK_STYLE[mark]
    if style then text = text .. "  |c" .. style.color .. "* " .. L[style.text] .. "|r" end
    return text
end

local function fillItem(target, entry, worn, slotKey)
    local id = entry.item
    target.itemId = id
    target.icon:SetTexture(getItemIcon(id))
    local name, quality = itemNameOf(id)
    local levelLine = levelText(id, slotKey)
    local r, g, b = colorFor(levelLine and 4 or quality)
    target.name:SetTextColor(r, g, b)
    target.name:SetText((name or ("[" .. id .. "]")) .. (worn[id] and ("  |cff52b7a8" .. L["Equipped"] .. "|r") or "") .. tagsOf(id, entry.share))
    target.where:SetText(levelLine and (levelLine .. "   " .. sourceText(id)) or sourceText(id))
    local count = math.floor(entry.share * entry.sample + 0.5)
    local color = bisSet[id] and BIS_COLOR or (ns.TierOf(entry.share) and TIER_COLOR[ns.TierOf(entry.share)]) or "ffffffff"
    target.share:SetText("|c" .. color .. count .. "|r |cff999999" .. ns.Percent(entry.share) .. "|r")
    local red, green, blue = tonumber(color:sub(3, 4), 16) / 255, tonumber(color:sub(5, 6), 16) / 255, tonumber(color:sub(7, 8), 16) / 255
    target.bar:SetValue(entry.share, { red, green, blue, 1 })
    target.holdText = holdTextOf(entry)
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    local _, class, spec = ns.ShownSpec()
    if class then ns.UseProfile(class .. "-" .. spec) end
    local db = ns.Settings()
    local worn = ns.EquippedItems()
    shownKey = class and (class .. "-" .. spec) or nil
    local contentKey = ns.ContentKey(class or "", spec or "", db.content, db.group)
    bisSet = ns.BisItems(class or "", spec or "", contentKey)
    local _, otherClass, otherSpec = ns.CompareSpec()
    local data
    if class and otherClass then
        data = ns.CommonRows(class, spec, contentKey, {
            class = otherClass, spec = otherSpec,
            content = ns.ContentKey(otherClass, otherSpec, db.content, db.group),
        }, ns.Filters(), nil)
    else
        data = ns.Rows(class or "", spec or "", contentKey, ns.Filters(), nil)
    end

    widgets.setSpecText(class and (ns.Title(class) .. " - " .. ns.Title(spec) .. (db.spec and "" or "  (you)")
        .. (otherClass and ("  +  " .. ns.Title(otherSpec)) or ""))
        or L["No data for this specialization."])
    -- the item switches belong to the items page (Overall) and the farming page (Mythic+ or Raid); the other pages
    -- keep the specialization and the player group. The farming page has no Overall: it reads as Mythic+.
    local onItems, onFarming = page == "items", page == "farming"
    local view = db.content
    if onFarming and view == "overall" then view = "mplus" end
    widgets.overall:SetActive(view == "overall")
    widgets.mplus:SetActive(view == "mplus")
    widgets.raid:SetActive(view == "raid")
    widgets.overall:SetShown(onItems)
    widgets.mplus:SetShown(onItems or onFarming)
    widgets.raid:SetShown(onItems or onFarming)
    widgets.key:SetShown(onItems and view ~= "raid")
    widgets.vault:SetShown(onItems and view ~= "raid")
    widgets.vault:SetChecked(db.vault)
    widgets.setKeyText(L["Key level"] .. ": " .. ns.KeyLabel(db.keyLevel))
    local groups = class and view == "mplus" and ns.HasGroups(class, spec)
    widgets.group:SetShown(groups and true or false)
    for _, choice in ipairs(GROUP_CHOICES) do
        if choice.value == db.group then widgets.setGroupText(L[choice.label]) end
    end
    widgets.stamp:SetText(KeyLootMasterMeta and (L["Data of"] .. " " .. KeyLootMasterMeta.generated:sub(1, 10)) or "")

    local any, firstWithItems = false, nil
    for index, row in ipairs(rows) do
        local entry = data[index]
        row.slotKey = entry.slot
        row.slot:SetText(L[SLOT_NAMES[entry.slot]])
        local top = entry.items[1]
        if top then
            any = true
            firstWithItems = firstWithItems or entry.slot
            row.icon:Show(); row.where:Show(); row.share:Show()
            fillItem(row, top, worn, entry.slot)
            local second = entry.items[2]
            if second then
                row.alt.itemId = second.item
                row.alt.icon:SetTexture(getItemIcon(second.item))
                row.alt.holdText = holdTextOf(second)
                row.alt:Show()
            else
                row.alt.itemId = nil
                row.alt:Hide()
            end
        else
            row.itemId = nil
            row.icon:Hide(); row.where:Hide(); row.share:Hide(); row.barBack:Hide(); row.barFill:Hide(); row.alt.itemId = nil; row.alt:Hide()
            row.name:SetTextColor(0.5, 0.5, 0.5)
            row.name:SetText("-")
        end
    end
    -- Keep the selected slot when it still has items, else the first slot that has some.
    local stillValid = false
    for _, entry in ipairs(data) do
        if entry.slot == selectedSlot and entry.items[1] then stillValid = true end
    end
    if not stillValid then selectedSlot = firstWithItems end
    for index, row in ipairs(rows) do
        if data[index].slot == selectedSlot then row.selected:Show() else row.selected:Hide() end
    end
    widgets.message:SetText(not class and L["No data for this specialization."]
        or (not any and L["Nothing matches the filters."]) or "")

    local selected
    for _, entry in ipairs(data) do if entry.slot == selectedSlot then selected = entry end end
    widgets.guide.itemId = nil
    if selected and selected.items[1] then
        local top = selected.items[1]
        widgets.detailTitle:SetText(L[SLOT_NAMES[selected.slot]])
        local facts = ns.StatText((ns.FactsOf(top.item)), {
            c = L["Crit"], h = L["Haste"], m = L["Mastery"], v = L["Versatility"] })
        widgets.detailSub:SetText(string.format(L["of %d players"], top.sample)
            .. ((facts ~= "") and ("  -  " .. facts) or ""))
        widgets.guide.itemId = top.item
        local kinds = ns.KindsOf(top.item)
        widgets.guide:SetShown(kinds.dungeon or kinds.raid or false)
        for index, row in ipairs(alternatives) do
            local entry = selected.items[index + 1]
            if entry then
                row:Show()
                fillItem(row, entry, worn, selected.slot)
            else
                row.itemId = nil
                row:Hide()
            end
        end
        widgets.altHeader:SetShown(#selected.items > 1)
    else
        widgets.detailTitle:SetText("")
        widgets.detailSub:SetText("")
        widgets.altHeader:Hide()
        widgets.guide:Hide()
        for _, row in ipairs(alternatives) do
            row.itemId = nil
            row:Hide()
        end
    end
    refreshPages(class, spec)
end

--- Shows one of the pages ("items", "stats", "gear", "talents", "players").
function UI.SetPage(name)
    page = name
    UI.Refresh()
end

function UI.Toggle()
    if not frame then build() end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        UI.Refresh()
    end
end
