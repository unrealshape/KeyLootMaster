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
    -- the class's tier set under the enchantments (placed by showTierSet, below the rows in use)
    gear.parent = parent
    gear.tierTitle = keep(makeText(parent, "GameFontNormal", 24, -420, 430))
    gear.tierText = keep(makeText(parent, "GameFontHighlight", 24, -446, 430))
    return parts
end

local LANG = (GetLocale and GetLocale() == "deDE") and "de" or "en"

--- The tier set of the class (name and what 2 and 4 pieces give) below the `rowsUsed` enchantment rows.
local function showTierSet(class, rowsUsed)
    local tier = class and ns.TierSetOf(class, LANG)
    gear.tierTitle:SetShown(tier ~= nil)
    gear.tierText:SetShown(tier ~= nil)
    if not tier then return end
    local top = -142 - rowsUsed * 26 - 14
    gear.tierTitle:ClearAllPoints()
    gear.tierTitle:SetPoint("TOPLEFT", gear.parent, "TOPLEFT", 24, top)
    gear.tierText:ClearAllPoints()
    gear.tierText:SetPoint("TOPLEFT", gear.parent, "TOPLEFT", 24, top - 24)
    gear.tierTitle:SetText(paint(GOLD, L["Tier set"] .. ": ") .. tier.name)
    local lines = {}
    for _, bonus in ipairs(tier.bonuses) do lines[#lines + 1] = paint(GOLD, "(" .. bonus.count .. ")") .. " " .. bonus.text end
    gear.tierText:SetText(table.concat(lines, "\n"))
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
        showTierSet(class, 0)
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
    showTierSet(class, used)
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

-- ------------------------------------------------------------------ farming page

-- Where to farm (ns.FarmingRoute): the dungeons (or bosses) in the order they are worth running, with the items
-- that drop there, on the left; the Crafted and Catalyst pieces and the other content's drops on the right.
local farming = { main = {}, side = {} }
local MAIN_LINES, SIDE_LINES = 22, 22
local SIDE_CAPS = { crafted = 7, catalyst = 5, other = 4 }
local MAIN_X, MAIN_WIDTH, SIDE_X, SIDE_WIDTH = 24, 560, 604, 272

local function buildFarmingLine(parent, x, y, width, wide)
    local line = CreateFrame("Button", nil, parent)
    line.isFarmingLine = true
    line.lineWidth = width
    line:SetSize(width, 20)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    line.back = line:CreateTexture(nil, "BACKGROUND")
    line.back:SetAllPoints()
    line.back:SetColorTexture(C.panel[1], C.panel[2], C.panel[3], C.panel[4] or 1)
    line.headText = Skin.Text(line, "GameFontNormal", 13)
    line.headText:SetPoint("LEFT", 8, 0)
    line.headText:SetWidth(width - 100)
    line.headText:SetJustifyH("LEFT")
    line.countText = Skin.Text(line, "GameFontDisableSmall", 11)
    line.countText:SetPoint("RIGHT", -8, 0)
    line.countText:SetWidth(90)
    line.countText:SetJustifyH("RIGHT")
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(16, 16)
    line.icon:SetPoint("LEFT", 8, 0)
    line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    line.itemText = Skin.Text(line, "GameFontHighlight", 12)
    line.itemText:SetPoint("LEFT", 30, 0)
    line.itemText:SetWidth(wide and 250 or 190)
    line.itemText:SetJustifyH("LEFT")
    line.shareText = Skin.Text(line, "GameFontHighlight", 12)
    line.shareText:SetPoint("RIGHT", -8, 0)
    line.shareText:SetWidth(46)
    line.shareText:SetJustifyH("RIGHT")
    if wide then
        line.bossText = Skin.Text(line, "GameFontDisableSmall", 11)
        line.bossText:SetPoint("LEFT", 286, 0)
        line.bossText:SetWidth(150)
        line.bossText:SetJustifyH("LEFT")
        line.slotText = Skin.Text(line, "GameFontDisableSmall", 11)
        line.slotText:SetPoint("LEFT", 440, 0)
        line.slotText:SetWidth(62)
        line.slotText:SetJustifyH("LEFT")
    end
    line:SetScript("OnEnter", function(self) if self.itemId and itemTooltip(self, self.itemId) then GameTooltip:Show() end end)
    line:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    line:SetScript("OnClick", function(self)
        if not self.itemId then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            linkItem(self.itemId)
        elseif UI.OpenInGuide then
            UI.OpenInGuide(self.itemId)
        end
    end)
    return line
end

--- Empties a line: nothing shown, nothing to click.
local function clearFarmingLine(line)
    line.itemId = nil
    line:Hide()
    line.back:Hide()
    for _, part in ipairs({ line.headText, line.countText, line.icon, line.itemText, line.shareText, line.bossText, line.slotText }) do
        part:Hide()
    end
    line.headText:SetText(""); line.countText:SetText(""); line.itemText:SetText("")
    line.shareText:SetText("")
    if line.bossText then line.bossText:SetText(""); line.slotText:SetText("") end
end

local function showFarmingHeader(line, head, count)
    clearFarmingLine(line)
    line:Show()
    line.back:Show()
    line.headText:SetWidth(line.lineWidth - (count and 100 or 16))
    line.headText:SetText(head); line.headText:Show()
    line.countText:SetText(count or ""); line.countText:SetShown(count ~= nil)
end

local function showFarmingItem(line, entry)
    clearFarmingLine(line)
    line:Show()
    line.back:Hide()
    line.itemId = entry.item
    line.icon:SetTexture(iconOf(entry.item)); line.icon:Show()
    local name, quality = UI.ItemName(entry.item)
    line.itemText:SetTextColor(UI.ItemColor(quality))
    local text = (name or ("[" .. entry.item .. "]")) .. (entry.worn and ("  " .. paint("ff52b7a8", L["Equipped"])) or "")
    if not line.bossText then
        -- the narrow column has no source column: a crafted piece names its profession behind the name
        local drop = ns.BestDrop(entry.item)
        if drop and drop.kind == "crafted" and drop.encounterName ~= "" then text = text .. "  " .. paint(GREY, L[drop.encounterName]) end
    end
    line.itemText:SetText(text)
    line.itemText:Show()
    line.shareText:SetText(ns.Percent(entry.share)); line.shareText:Show()
    if line.bossText then
        line.bossText:SetText(entry.boss or ""); line.bossText:Show()
        line.slotText:SetText(L[ns.SLOT_NAMES[entry.slot]] or entry.slot); line.slotText:Show()
    end
end

local function itemCount(count)
    return count == 1 and L["1 item"] or string.format(L["%d items"], count)
end

local function buildFarming(parent)
    local parts = {}
    local function keep(part) parts[#parts + 1] = part; return part end
    -- the parts to hide with the page: a line and everything on it
    local function keepLine(line)
        keep(line)
        for _, part in ipairs({ line.back, line.headText, line.countText, line.icon, line.itemText, line.shareText,
            line.bossText, line.slotText }) do
            keep(part)
        end
        return line
    end
    for index = 1, MAIN_LINES do
        farming.main[index] = keepLine(buildFarmingLine(parent, MAIN_X, -118 - (index - 1) * 21, MAIN_WIDTH, true))
    end
    for index = 1, SIDE_LINES do
        farming.side[index] = keepLine(buildFarmingLine(parent, SIDE_X, -118 - (index - 1) * 21, SIDE_WIDTH, false))
    end
    farming.empty = keep(makeText(parent, "GameFontDisable", 24, -124, 600))
    return parts
end

--- The lines of the left column: a header per group, its items below; cut at a group's end when they do not all fit.
local function mainFarmingLines(route)
    local lines, starts = {}, {}
    for rank, group in ipairs(route.groups) do
        starts[#starts + 1] = #lines + 1
        local head = paint(GOLD, rank .. "  " .. group.name) .. (group.sub and ("  " .. paint(GREY, group.sub)) or "")
        lines[#lines + 1] = { head = head, count = itemCount(#group.items) }
        for _, entry in ipairs(group.items) do lines[#lines + 1] = { entry = entry } end
    end
    if #lines <= MAIN_LINES then return lines end
    -- keep whole groups while a line stays free for the note; the first group is cut when it alone is too long
    local keepUntil, groupsKept = MAIN_LINES - 1, 0
    for index in ipairs(starts) do
        local last = (starts[index + 1] or (#lines + 1)) - 1
        if last <= MAIN_LINES - 1 then keepUntil, groupsKept = last, index end
    end
    local cut = {}
    for index = 1, keepUntil do cut[index] = lines[index] end
    cut[#cut + 1] = { note = string.format(L["+%d more"], #route.groups - groupsKept) }
    return cut
end

--- The lines of the right column: Crafted, Catalyst, the other content's drops; each with its items.
local function sideFarmingLines(route, class)
    local lines = {}
    local other = route.kind == "dungeon" and L["Raid drops Mythic+ players wear"] or L["Dungeon drops raiders wear"]
    for _, section in ipairs({
        { "crafted", L["Crafted"] }, { "catalyst", L["Catalyst / tier"] }, { "other", other },
    }) do
        local list = route[section[1]]
        if #list > 0 then
            lines[#lines + 1] = { head = paint(GOLD, section[2]), count = itemCount(#list) }
            local slots = {}
            for index, entry in ipairs(list) do
                if index > SIDE_CAPS[section[1]] then break end
                lines[#lines + 1] = { entry = entry }
                slots[#slots + 1] = entry.slot
            end
            if section[1] == "catalyst" and route.kind == "dungeon" then
                -- where the raw pieces of these slots drop (any piece of the slot and armor type will do)
                local places = {}
                for index, dungeon in ipairs(ns.CatalystDungeons(class, slots)) do
                    if index > 4 then break end
                    places[#places + 1] = string.format("%s (%d)", dungeon.name, dungeon.count)
                end
                if #places > 0 then
                    lines[#lines + 1] = { note = L["Raw pieces:"] .. " " .. table.concat(places, " - ", 1, math.min(2, #places)) }
                end
                if #places > 2 then
                    lines[#lines + 1] = { note = table.concat(places, " - ", 3, #places) }
                end
            end
        end
    end
    return lines
end

local function fillFarmingColumn(column, lines)
    for index, line in ipairs(column) do
        local what = lines[index]
        if not what then
            clearFarmingLine(line)
        elseif what.entry then
            showFarmingItem(line, what.entry)
        elseif what.note then
            showFarmingHeader(line, paint(GREY, what.note), nil)
            line.back:Hide()
        else
            showFarmingHeader(line, what.head, what.count)
        end
    end
end

local function refreshFarming(class, spec, group)
    local view = ns.Settings().content == "raid" and "raid" or "mplus"
    local route = class and ns.FarmingRoute(class, spec, ns.ContentKey(class, spec, view, group), ns.EquippedItems())
    local main = route and mainFarmingLines(route) or {}
    local side = route and sideFarmingLines(route, class) or {}
    fillFarmingColumn(farming.main, main)
    fillFarmingColumn(farming.side, side)
    local nothing = #main == 0 and #side == 0
    farming.empty:SetText(not class and L["No data for this specialization."] or L["Nothing to farm for this specialization yet."])
    farming.empty:SetShown(nothing)
    if nothing then return nil end
    return L["The score of a dungeon adds up the share of top players who wear what drops there. What you wear is marked and does not count."]
end

UI.RegisterPage("farming", { build = buildFarming, refresh = refreshFarming })
UI.RegisterPage("gear", { build = buildGear, refresh = refreshGear })
UI.RegisterPage("talents", { build = buildTalents, refresh = refreshTalents })
UI.RegisterPage("players", { build = buildPlayers, refresh = refreshPlayers })
