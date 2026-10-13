-- The pages next to the item list: enchantments and gems, talents, the best players.
-- Every page reads KeyLootMasterGear[class][spec][group] (Data/Gear.lua, made by the pipeline).
local _, ns = ...

local L = ns.L
local UI = ns.UI

local GOLD, WHITE, GREY, GREEN, RED = "ffffd100", "ffffffff", "ff999999", "ff52e052", "ffe05252"
local GEM_COLORS = {
    red = "ffff5050", green = "ff50d050", purple = "ffb060ff", blue = "ff5aa0ff", meta = GOLD, other = WHITE,
}
local MAX_SLOT_ROWS = 14
local TOP_PLAYERS = 10

local function paint(color, text) return "|c" .. color .. text .. "|r" end

local Skin = ns.Skin
local C = Skin.C

local FALLBACK_ICON = 134400

--- The icon of an item (a gem, an enchanting item), a question mark when the game does not know it yet.
local function iconOf(id)
    local get = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return (get and id and get(id)) or FALLBACK_ICON
end

--- A chat link of an item; without the game's own link (item not loaded yet) a plain one.
local function itemLink(id, name)
    local info = C_Item and C_Item.GetItemInfo
    local link = info and select(2, info(id))
    return link or string.format("|Hitem:%d|h[%s]|h", id, name or id)
end

--- Shift-click puts the item into the chat edit box, as with every item link.
local function linkItem(id, name)
    if id and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
        ChatEdit_InsertLink(itemLink(id, name))
    end
end

--- The game's item tooltip for an item id on an owner; false when there is none to show.
local function itemTooltip(owner, id)
    if not (GameTooltip and id and GameTooltip.SetItemByID) then return false end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(id)
    return true
end

--- "1x Meta   2x Green" with every color in its own color.
local function coloredSignature(sig)
    local parts = {}
    for _, color in ipairs(ns.GEM_ORDER) do
        local count = sig[color]
        if count and count > 0 then
            local label = color:sub(1, 1):upper() .. color:sub(2)
            parts[#parts + 1] = count .. "x " .. paint(GEM_COLORS[color] or WHITE, L[label])
        end
    end
    return table.concat(parts, "   ")
end

local function makeText(parent, template, x, y, width, justify)
    local text = Skin.Text(parent, template)
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then text:SetWidth(width) end
    text:SetJustifyH(justify or "LEFT")
    return text
end

--- Shaded by how many of the group chose it: gold from 80 %, white from 30 %, grey below.
local function shareColor(count, total)
    local share = total > 0 and count / total or 0
    if share >= 0.8 then return GOLD end
    if share >= 0.3 then return WHITE end
    return GREY
end

-- ------------------------------------------------------------------ the copy box for an import string

local copyBox

--- Shows an import string in a small window with the text selected: Ctrl+C, then paste it into the
--- import window of the talent frame.
local function showCopyBox(code)
    if not copyBox then
        copyBox = CreateFrame("Frame", "KeyLootMasterCopyBox", UIParent)
        copyBox:SetSize(540, 116)
        copyBox:SetPoint("CENTER", 0, 120)
        copyBox:SetFrameStrata("DIALOG")
        copyBox:EnableMouse(true)
        Skin.Box(copyBox, C.window, C.borderStrong)
        copyBox.hint = Skin.Text(copyBox, "GameFontHighlight", 13)
        copyBox.hint:SetPoint("TOPLEFT", 18, -18)
        copyBox.hint:SetWidth(504)
        copyBox.hint:SetText(L["Press Ctrl+C, then paste it into the talent import window."])
        copyBox.edit = CreateFrame("EditBox", nil, copyBox)
        copyBox.edit:SetSize(504, 30)
        copyBox.edit:SetPoint("TOPLEFT", 18, -60)
        Skin.Box(copyBox.edit, C.field, C.border)
        copyBox.edit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        copyBox.edit:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        copyBox.edit:SetTextInsets(8, 8, 0, 0)
        copyBox.edit:SetAutoFocus(true)
        copyBox.edit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
        if UISpecialFrames then table.insert(UISpecialFrames, "KeyLootMasterCopyBox") end
    end
    copyBox.edit:SetText(code)
    copyBox:Show()
    copyBox.edit:SetFocus()
    copyBox.edit:HighlightText()
end

-- ------------------------------------------------------------------ gear page

local gear = { rows = {}, gems = {}, sets = {}, embellishments = {} }

local function buildGear(parent)
    local parts = {}
    local function keep(part) parts[#parts + 1] = part; return part end
    gear.enchantTitle = keep(makeText(parent, "GameFontNormalLarge", 24, -112))
    gear.enchantTitle:SetText(L["Enchantments"])
    for index = 1, MAX_SLOT_ROWS do
        local row = keep(CreateFrame("Button", nil, parent))
        row:SetSize(420, 24)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -142 - (index - 1) * 26)
        row.slot = makeText(row, "GameFontNormalSmall", 0, -6, 80)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 84, -3)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = makeText(row, "GameFontHighlight", 108, -4, 226)
        row.count = makeText(row, "GameFontHighlight", 336, -4, 80, "RIGHT")
        -- the item that applies the top enchantment: its own tooltip, and Shift-click links it in the chat
        row:SetScript("OnEnter", function(self)
            if not (GameTooltip and self.options) then return end
            local top = self.options[1]
            if top.item and itemTooltip(self, top.item) then
                GameTooltip:AddLine(" ")
            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            end
            GameTooltip:AddLine(L[ns.SLOT_NAMES[self.slotKey]], 1, 0.82, 0)
            for _, option in ipairs(self.options) do
                GameTooltip:AddDoubleLine(option.name, option.n .. "/" .. (self.total or 0), 1, 1, 1, 0.8, 0.8, 0.8)
            end
            if top.item then GameTooltip:AddLine(L["Shift-click links it in the chat."], 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        row:SetScript("OnClick", function(self)
            local top = self.options and self.options[1]
            if top and top.item then linkItem(top.item, top.name) end
        end)
        gear.rows[index] = row
    end
    gear.gemTitle = keep(makeText(parent, "GameFontNormalLarge", 480, -112))
    gear.gemTitle:SetText(L["Gems"])
    -- a gem: its icon, its name and how many top players use it; the item's own tooltip, Shift-click links it
    for index = 1, 6 do
        local gem = keep(CreateFrame("Button", nil, parent))
        gem:SetSize(330, 22)
        gem:SetPoint("TOPLEFT", parent, "TOPLEFT", 480, -142 - (index - 1) * 22)
        gem.icon = gem:CreateTexture(nil, "ARTWORK")
        gem.icon:SetSize(18, 18)
        gem.icon:SetPoint("TOPLEFT", gem, "TOPLEFT", 0, -2)
        gem.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        gem.text = makeText(gem, "GameFontHighlight", 24, -4, 300)
        gem:SetScript("OnEnter", function(self)
            if self.itemId and itemTooltip(self, self.itemId) then
                GameTooltip:AddLine(L["Shift-click links it in the chat."], 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end
        end)
        gem:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        gem:SetScript("OnClick", function(self) linkItem(self.itemId, self.gemName) end)
        gear.gems[index] = gem
    end
    gear.setTitle = keep(makeText(parent, "GameFontNormalLarge", 480, -290))
    gear.setTitle:SetText(L["Gem sets"])
    gear.setHint = keep(makeText(parent, "GameFontDisableSmall", 480, -314, 340))
    gear.setHint:SetText(L["A gem set is the mix of gem colors the top players wear. Each line is one mix and how many of them wear it. The You line compares your gems with the most common mix: +1 Red means you lack one red gem."])
    for index = 1, 3 do gear.sets[index] = keep(makeText(parent, "GameFontHighlight", 480, -366 - (index - 1) * 22, 340)) end
    gear.own = keep(makeText(parent, "GameFontHighlight", 480, -438, 340))
    gear.embTitle = keep(makeText(parent, "GameFontNormalLarge", 480, -474))
    gear.embTitle:SetText(L["Embellishments"])
    for index = 1, 3 do gear.embellishments[index] = keep(makeText(parent, "GameFontHighlight", 480, -504 - (index - 1) * 22, 330)) end
    gear.empty = keep(makeText(parent, "GameFontDisable", 24, -124, 600))
    gear.empty:SetText(L["No gear data for this specialization yet."])
    return parts
end

local function refreshGear(class, spec, group)
    local info = class and ns.GearInfo(class, spec, group)
    gear.empty:SetShown(info == nil)
    for _, part in ipairs({ gear.enchantTitle, gear.gemTitle, gear.setTitle, gear.setHint, gear.own, gear.embTitle }) do
        part:SetShown(info ~= nil)
    end
    for _, list in ipairs({ gear.sets, gear.embellishments }) do
        for _, text in ipairs(list) do text:SetShown(info ~= nil) end
    end
    if not info then
        for _, gem in ipairs(gear.gems) do gem:Hide() end
        for _, row in ipairs(gear.rows) do row:Hide() end
        return nil
    end
    local total = info.n or 0
    local used = 0
    for _, slot in ipairs(ns.SLOT_ORDER) do
        local options = info.enchants and info.enchants[slot]
        if options and options[1] and used < MAX_SLOT_ROWS then
            used = used + 1
            local row = gear.rows[used]
            local top = options[1]
            row.slotKey, row.options, row.total = slot, options, total
            row.slot:SetText(L[ns.SLOT_NAMES[slot]])
            row.name:SetText(top.name)
            row.icon:SetShown(top.item ~= nil)
            if top.item then row.icon:SetTexture(iconOf(top.item)) end
            local mine = ns.OwnEnchantId(slot)
            local mark = ""
            if mine ~= nil then
                mark = (mine == top.id) and ("  " .. paint(GREEN, "OK")) or ("  " .. paint(RED, "!"))
            end
            row.count:SetText(paint(shareColor(top.n, total), top.n .. "/" .. total) .. mark)
            row:Show()
        end
    end
    for index = used + 1, MAX_SLOT_ROWS do gear.rows[index]:Hide() end
    for index, button in ipairs(gear.gems) do
        local gem = info.gems and info.gems[index]
        button:SetShown(gem ~= nil)
        button.itemId, button.gemName = gem and gem.id, gem and gem.name
        if gem then
            button.icon:SetTexture(iconOf(gem.id))
            button.text:SetText(paint(GEM_COLORS[gem.color] or WHITE, gem.name) .. "   " ..
                paint(shareColor(gem.n, total), gem.n .. "/" .. total))
        end
    end
    for index, text in ipairs(gear.sets) do
        local set = info.gemSets and info.gemSets[index]
        text:SetText(set and (paint(shareColor(set.n, total), ns.Percent(total > 0 and set.n / total or 0)) ..
            " " .. paint(GREY, "(" .. set.n .. "/" .. total .. ")") .. "   " .. coloredSignature(set.sig)) or "")
    end
    local top = info.gemSets and info.gemSets[1]
    local own = ns.OwnGemSignature()
    if top and own then
        local difference = ns.SigDiff(own, top.sig, L)
        gear.own:SetText(paint(GREY, L["You"] .. ": ") .. ns.SigText(own, L) ..
            (difference == "" and ("   " .. paint(GREEN, "OK")) or ("   " .. paint(RED, difference))))
    else
        gear.own:SetText("")
    end
    for index, text in ipairs(gear.embellishments) do
        local item = info.embellishments and info.embellishments[index]
        text:SetText(item and (item.name .. "   " .. paint(GREY, item.n)) or "")
    end
    return string.format(L["Average of the %d top players"], total)
end

-- ------------------------------------------------------------------ talents page

local talents = { builds = {}, columns = {} }
local COLUMN_TITLES = { "Class talents", "Specialization talents", "Hero talents" }

local function say(text)
    print("|cffe8b64aKeyLootMaster|r: " .. text)
end

--- Hands a build to the game's own talent importer, which adds it as a new loadout. The talent window
--- is opened first (it is a load-on-demand addon). When the importer is missing, changed or refuses the
--- string, the copy box opens instead, so the player can still paste it by hand.
local function applyBuild(build)
    if not build then return end
    if InCombatLockdown and InCombatLockdown() then
        say(L["Not possible in combat."])
        return
    end
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells")
        pcall(C_AddOns.LoadAddOn, "Blizzard_ClassTalentUI")
    end
    local window = PlayerSpellsFrame or ClassTalentFrame
    local tab = (PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame) or (ClassTalentFrame and ClassTalentFrame.TalentsTab)
    if window and tab and tab.ImportLoadout then
        if window.IsShown and not window:IsShown() and window.Show then pcall(window.Show, window) end
        local name = "KLM " .. (build.hero or L["Build"])
        local ok, done = pcall(tab.ImportLoadout, tab, build.code, name)
        if ok and done then
            say(L["Build applied as a new loadout."])
            return
        end
    end
    say(L["Could not apply the build; the import string is in the copy box."])
    showCopyBox(build.code)
end

local function buildTalents(parent)
    local parts = {}
    local function keep(part) parts[#parts + 1] = part; return part end
    talents.title = keep(makeText(parent, "GameFontNormalLarge", 24, -112))
    talents.title:SetText(L["Builds"])
    for index = 1, 3 do
        local row = keep(CreateFrame("Frame", nil, parent))
        row:SetSize(852, 52)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -142 - (index - 1) * 58)
        Skin.Box(row, C.panel, C.border)
        row.head = makeText(row, "GameFontHighlight", 16, -10, 520)
        row.code = makeText(row, "GameFontDisableSmall", 16, -30, 520)
        row.apply = Skin.Button(row, L["Apply build"], 140, 32, "primary")
        row.apply:SetPoint("RIGHT", row, "RIGHT", -106, 0)
        row.apply:SetScript("OnClick", function() applyBuild(row.build) end)
        row.copy = Skin.Button(row, L["Copy"], 84, 32, "soft")
        row.copy:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.copy:SetScript("OnClick", function() if row.build then showCopyBox(row.build.code) end end)
        talents.builds[index] = row
    end
    talents.heroes = keep(makeText(parent, "GameFontHighlight", 24, -328, 840))
    for index = 1, #COLUMN_TITLES do
        talents.columns[index] = keep(makeText(parent, "GameFontHighlightSmall", 24 + (index - 1) * 290, -362, 270))
    end
    talents.empty = keep(makeText(parent, "GameFontDisable", 24, -124, 600))
    talents.empty:SetText(L["No talent data for this specialization yet."])
    return parts
end

local function refreshTalents(class, spec, group)
    local info = class and ns.GearInfo(class, spec, group)
    local has = info ~= nil and ((info.builds and info.builds[1]) or (info.talents and info.talents[1])) ~= nil
    talents.empty:SetShown(not has)
    talents.title:SetShown(has)
    talents.heroes:SetShown(has)
    for _, column in ipairs(talents.columns) do column:SetShown(has) end
    if not has then
        for _, row in ipairs(talents.builds) do row:Hide() end
        return nil
    end
    local total = info.n or 0
    for index, row in ipairs(talents.builds) do
        local build = info.builds and info.builds[index]
        row.build = build
        if build then
            row:Show()
            row.head:SetText(paint(index == 1 and GOLD or WHITE, L["Build"] .. " " .. index) ..
                (build.hero and ("   " .. build.hero) or "") .. "   " .. paint(GREY, string.format(L["%d players"], build.n)))
            row.code:SetText(build.code:sub(1, 90) .. (#build.code > 90 and "..." or ""))
        else
            row:Hide()
        end
    end
    local heroes = {}
    for _, hero in ipairs(info.heroes or {}) do heroes[#heroes + 1] = hero.name .. " " .. paint(GREY, hero.n) end
    talents.heroes:SetText(#heroes > 0 and (paint(GOLD, L["Hero talents"] .. ": ") .. table.concat(heroes, "   ")) or "")
    local byTree = { class = {}, spec = {}, hero = {} }
    for _, talent in ipairs(info.talents or {}) do
        local list = byTree[talent.tree]
        if list then list[#list + 1] = talent end
    end
    for index, tree in ipairs({ "class", "spec", "hero" }) do
        local lines = { paint(GOLD, L[COLUMN_TITLES[index]]) }
        for position, talent in ipairs(byTree[tree]) do
            if position > 12 then break end
            lines[#lines + 1] = paint(shareColor(talent.n, total), talent.name) .. "  " .. paint(GREY, talent.n)
        end
        talents.columns[index]:SetText(table.concat(lines, "\n"))
    end
    return string.format(L["Average of the %d top players"], total) .. "   -   " ..
        L["Applying adds a new loadout in the talent window and overwrites nothing."]
end

-- ------------------------------------------------------------------ players page

local players = { rows = {} }

local function buildPlayers(parent)
    local parts = {}
    local function keep(part) parts[#parts + 1] = part; return part end
    players.title = keep(makeText(parent, "GameFontNormalLarge", 24, -112))
    players.title:SetText(L["Best players"])
    -- the head of the table, so the columns need no guessing
    players.head = {}
    for _, column in ipairs({
        { "#", 24, 30 }, { "Name", 60, 200 }, { "Realm", 270, 190 },
        { "Race", 470, 110 }, { "Item level", 590, 60 }, { "Rating", 660, 80 },
    }) do
        local label = keep(makeText(parent, "GameFontDisableSmall", column[2], -142, column[3]))
        label:SetText(column[1] == "#" and "#" or L[column[1]])
        players.head[#players.head + 1] = label
    end
    for index = 1, TOP_PLAYERS do
        local y = -164 - (index - 1) * 30
        players.rows[index] = {
            rank = keep(makeText(parent, "GameFontNormal", 24, y, 30)),
            name = keep(makeText(parent, "GameFontHighlight", 60, y, 200)),
            realm = keep(makeText(parent, "GameFontDisable", 270, y, 190)),
            race = keep(makeText(parent, "GameFontHighlight", 470, y, 110)),
            ilvl = keep(makeText(parent, "GameFontHighlight", 590, y, 60)),
            rating = keep(makeText(parent, "GameFontHighlight", 660, y, 80)),
        }
    end
    players.empty = keep(makeText(parent, "GameFontDisable", 24, -124, 600))
    players.empty:SetText(L["No player data for this specialization yet."])
    return parts
end

local function refreshPlayers(class, spec, group)
    local info = class and ns.GearInfo(class, spec, group)
    local list = info and info.players or {}
    players.empty:SetShown(#list == 0)
    players.title:SetShown(#list > 0)
    for _, label in ipairs(players.head) do label:SetShown(#list > 0) end
    for index, row in ipairs(players.rows) do
        local player = list[index]
        for _, field in pairs(row) do field:SetShown(player ~= nil) end
        if player then
            row.rank:SetText(index)
            row.name:SetText(player.name)
            row.realm:SetText((player.realm or "") .. (player.region and (" (" .. player.region:upper() .. ")") or ""))
            row.race:SetText(player.race or "")
            row.ilvl:SetText(player.ilvl and (player.ilvl .. " ilvl") or "")
            row.rating:SetText(paint(GOLD, player.rating or (player.key and ("+" .. player.key)) or ""))
        end
    end
    return nil
end

UI.RegisterPage("gear", { build = buildGear, refresh = refreshGear })
UI.RegisterPage("talents", { build = buildTalents, refresh = refreshTalents })
UI.RegisterPage("players", { build = buildPlayers, refresh = refreshPlayers })
