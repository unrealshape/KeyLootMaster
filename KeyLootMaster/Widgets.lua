-- The flat look of the window: colors, text, buttons, switches and the dropdown button.
-- Nothing here uses a Blizzard frame template; everything is drawn from solid textures.
local ADDON, ns = ...

local Skin = {}
ns.Skin = Skin

local C = {
    window = { 0.067, 0.078, 0.106, 0.97 },
    header = { 0.082, 0.098, 0.133, 1 },
    panel = { 0.098, 0.114, 0.153, 1 },
    field = { 0.102, 0.122, 0.165, 1 },
    border = { 0.165, 0.188, 0.251, 1 },
    borderStrong = { 0.29, 0.33, 0.44, 1 },
    text = { 0.90, 0.914, 0.941, 1 },
    dim = { 0.68, 0.71, 0.78, 1 },
    muted = { 0.435, 0.47, 0.55, 1 },
    accent = { 0.91, 0.714, 0.29, 1 },
    ink = { 0.067, 0.078, 0.106, 1 },
    good = { 0.32, 0.84, 0.64, 1 },
    bad = { 0.88, 0.32, 0.32, 1 },
}
Skin.C = C

--- A color table with another alpha.
function Skin.Alpha(color, alpha) return { color[1], color[2], color[3], alpha } end

local function paintTexture(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

--- A solid texture over the whole frame.
function Skin.Fill(frame, color, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    paintTexture(texture, color)
    return texture
end

--- A one pixel frame around the frame; returns an object with :SetColor(color).
function Skin.Border(frame, color)
    local edges = {}
    local function edge(a, b, width, height)
        local texture = frame:CreateTexture(nil, "BORDER")
        texture:SetPoint(a, frame, a, 0, 0)
        texture:SetPoint(b, frame, b, 0, 0)
        if width then texture:SetWidth(width) end
        if height then texture:SetHeight(height) end
        paintTexture(texture, color)
        edges[#edges + 1] = texture
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    local border = {}
    function border:SetColor(next) for _, texture in ipairs(edges) do paintTexture(texture, next) end end
    return border
end

--- Background and one pixel border.
function Skin.Box(frame, background, border)
    local fill = Skin.Fill(frame, background)
    local edge = border and Skin.Border(frame, border) or nil
    return fill, edge
end

-- ------------------------------------------------------------------ text

-- The game font templates the pages name, mapped to a size and a color of the skin.
local TEXT_STYLES = {
    GameFontNormalLarge = { 17, "text" },
    GameFontNormal = { 13, "accent" },
    GameFontNormalSmall = { 11, "muted" },
    GameFontHighlight = { 13, "text" },
    GameFontHighlightSmall = { 12, "dim" },
    GameFontDisable = { 13, "muted" },
    GameFontDisableSmall = { 11, "muted" },
}

local function fontFile()
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

--- A text line in the skin's font; `template` is a game font name or nil for normal text.
function Skin.Text(parent, template, size, color)
    local style = TEXT_STYLES[template or "GameFontHighlight"] or TEXT_STYLES.GameFontHighlight
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(fontFile(), size or style[1], "")
    local tint = color or C[style[2]]
    text:SetTextColor(tint[1], tint[2], tint[3], tint[4] or 1)
    text:SetJustifyH("LEFT")
    return text
end

-- ------------------------------------------------------------------ buttons

local KINDS = {
    ghost = { fill = C.field, edge = C.border, text = C.text, hover = C.panel, onFill = C.accent, onText = C.ink },
    primary = { fill = C.accent, edge = C.accent, text = C.ink, hover = { 1, 0.80, 0.38, 1 }, onFill = C.accent, onText = C.ink },
    chip = { fill = C.window, edge = C.border, text = C.dim, hover = C.panel, onFill = Skin.Alpha(C.accent, 0.16), onText = C.accent, onEdge = C.accent },
    soft = { fill = C.field, edge = C.border, text = C.dim, hover = C.panel, onFill = { 0.165, 0.188, 0.251, 1 }, onText = C.text, onEdge = C.borderStrong },
}

--- A flat button. kind: "ghost", "primary", "chip" or "soft". :SetActive(on) lights it up;
--- :SetText(text) sets the label.
function Skin.Button(parent, text, width, height, kind)
    local look = KINDS[kind or "ghost"]
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height or 28)
    button.fill, button.edge = Skin.Box(button, look.fill, look.edge)
    button.label = Skin.Text(button, "GameFontHighlight", 12, look.text)
    button.label:SetPoint("CENTER", 0, 0)
    button.label:SetJustifyH("CENTER")
    button.look = look
    button.active = false
    local function paint(hover)
        local fill = button.active and look.onFill or (hover and look.hover) or look.fill
        local text = button.active and look.onText or look.text
        paintTexture(button.fill, fill)
        button.edge:SetColor(button.active and (look.onEdge or look.edge) or look.edge)
        button.label:SetTextColor(text[1], text[2], text[3], text[4] or 1)
    end
    button.paint = paint
    function button:SetActive(on) self.active = on and true or false; paint(false) end
    function button:SetText(value) self.text = value; self.label:SetText(value) end
    button:SetScript("OnEnter", function() paint(true) end)
    button:SetScript("OnLeave", function() paint(false) end)
    if text then button:SetText(text) end
    return button
end

--- A tab: text with a line under it when active.
function Skin.Tab(parent, text, width, height)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(width, height)
    tab.label = Skin.Text(tab, "GameFontHighlight", 13, C.muted)
    tab.label:SetPoint("CENTER", 0, 1)
    tab.label:SetJustifyH("CENTER")
    tab.line = tab:CreateTexture(nil, "OVERLAY")
    tab.line:SetPoint("BOTTOMLEFT", 0, 0)
    tab.line:SetPoint("BOTTOMRIGHT", 0, 0)
    tab.line:SetHeight(2)
    paintTexture(tab.line, C.accent)
    tab.line:Hide()
    function tab:SetText(value) self.text = value; self.label:SetText(value) end
    function tab:SetActive(on)
        self.active = on and true or false
        self.line:SetShown(self.active)
        local color = self.active and C.text or C.muted
        self.label:SetTextColor(color[1], color[2], color[3], 1)
    end
    tab:SetScript("OnEnter", function(self) if not self.active then self.label:SetTextColor(C.dim[1], C.dim[2], C.dim[3], 1) end end)
    tab:SetScript("OnLeave", function(self) self:SetActive(self.active) end)
    tab:SetText(text)
    return tab
end

--- An on/off switch with a label: :SetChecked(on), :GetChecked(); `onClick(on)` runs on a click.
function Skin.Toggle(parent, label, onClick)
    local toggle = CreateFrame("CheckButton", nil, parent)
    toggle:SetSize(34, 20)
    toggle.track = toggle:CreateTexture(nil, "BACKGROUND")
    toggle.track:SetPoint("LEFT", 0, 0)
    toggle.track:SetSize(30, 16)
    toggle.knob = toggle:CreateTexture(nil, "OVERLAY")
    toggle.knob:SetSize(12, 12)
    toggle.caption = Skin.Text(toggle, "GameFontHighlightSmall", 12, C.dim)
    toggle.caption:SetPoint("LEFT", toggle.track, "RIGHT", 8, 0)
    toggle.caption:SetText(label)
    -- the label is part of the click area
    local width = toggle.caption:GetStringWidth()
    if type(width) == "number" then toggle:SetWidth(34 + width + 4) end
    toggle.on = false
    local function paint()
        paintTexture(toggle.track, toggle.on and Skin.Alpha(C.accent, 0.85) or C.borderStrong)
        paintTexture(toggle.knob, toggle.on and C.ink or C.dim)
        toggle.knob:ClearAllPoints()
        toggle.knob:SetPoint("LEFT", toggle.track, "LEFT", toggle.on and 16 or 2, 0)
    end
    function toggle:SetChecked(on) self.on = on and true or false; paint() end
    function toggle:GetChecked() return self.on end
    toggle:SetScript("OnClick", function(self)
        self.on = not self.on
        paint()
        if onClick then onClick(self.on) end
    end)
    toggle:SetScript("OnEnter", function(self) self.caption:SetTextColor(C.text[1], C.text[2], C.text[3], 1) end)
    toggle:SetScript("OnLeave", function(self) self.caption:SetTextColor(C.dim[1], C.dim[2], C.dim[3], 1) end)
    paint()
    return toggle
end

--- A thin bar: a back track and a fill whose width is set with :SetValue(share, color).
function Skin.Bar(parent, width, height)
    local bar = { width = width }
    bar.back = parent:CreateTexture(nil, "ARTWORK")
    bar.back:SetSize(width, height)
    paintTexture(bar.back, C.border)
    bar.fill = parent:CreateTexture(nil, "OVERLAY")
    bar.fill:SetSize(width, height)
    bar.fill:SetPoint("LEFT", bar.back, "LEFT", 0, 0)
    function bar:SetValue(share, color)
        paintTexture(self.fill, color)
        self.fill:SetWidth(math.max(2, self.width * math.min(1, math.max(0, share))))
        self.back:Show(); self.fill:Show()
    end
    function bar:Hide() self.back:Hide(); self.fill:Hide() end
    return bar
end

-- ------------------------------------------------------------------ dropdown

--- A button that opens a menu. `fill(root)` builds the menu with the game's menu system
--- (root:CreateRadio / CreateButton); without that system a click calls `cycle()` instead.
--- Returns the button and a function that sets its label.
function Skin.Dropdown(parent, width, fill, cycle)
    local button = Skin.Button(parent, nil, width, 28, "ghost")
    button.isDropdown = true
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", 12, 0)
    button.label:SetPoint("RIGHT", -24, 0)
    button.label:SetJustifyH("LEFT")
    button.chevron = Skin.Text(button, "GameFontHighlightSmall", 9, C.muted)
    button.chevron:SetPoint("RIGHT", -10, -1)
    button.chevron:SetText("v")
    button.menuFn = function(_, root) fill(root) end
    button:SetScript("OnClick", function(self)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, self.menuFn)
        elseif cycle then
            cycle()
        end
    end)
    return button, function(label) button:SetText(label) end
end
