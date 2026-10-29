-- Hunter Weapon Sounds - menu
-- Shown in: Options > AddOns > Hunter Weapon Sounds, as a standalone window
-- (/hws or the minimap button).

local ADDON_NAME, ns = ...

local PANEL_W = 600
local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local panels = {}      -- every built copy of the menu (options page + window)
local picker, catcher  -- shared "choose a sound" list

local function RefreshAll()
    for _, p in ipairs(panels) do p.Refresh() end
end

local function MakeBackdrop(f, r, g, b, a)
    if f.SetBackdrop then
        f:SetBackdrop(BACKDROP)
        f:SetBackdropColor(r, g, b, a)
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end
end

local function Label(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    return b
end

local function EditBox(parent, w)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetAutoFocus(false)
    e:SetFontObject("ChatFontNormal")
    return e
end

------------------------------------------------------------------------
-- Sound picker (a scrolling list of built-in + custom sounds)
------------------------------------------------------------------------
local pickerRows = {}

local function BuildPicker()
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(50)
    catcher:Hide()

    picker = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    picker:SetSize(340, 280)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(60)
    picker:EnableMouse(true)
    MakeBackdrop(picker, 0.08, 0.08, 0.1, 0.97)
    picker:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(300, 10)
    scroll:SetScrollChild(content)
    picker.content = content

    local function Close() picker:Hide(); catcher:Hide() end
    picker.Close = Close
    catcher:SetScript("OnClick", Close)
end

local function PickerRow(i)
    local row = pickerRows[i]
    if row then return row end
    row = CreateFrame("Button", nil, picker.content)
    row:SetSize(296, 20)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetPoint("RIGHT", -24, 0)
    row.text:SetJustifyH("LEFT")
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)
    row.del = CreateFrame("Button", nil, row)
    row.del:SetSize(18, 18)
    row.del:SetPoint("RIGHT", -2, 0)
    local x = row.del:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    x:SetPoint("CENTER")
    x:SetText("|cffff4040X|r")
    row.del:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove from your custom list")
        GameTooltip:Show()
    end)
    row.del:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pickerRows[i] = row
    return row
end

-- onPick(name) is called with the chosen entry ("" for none)
local function OpenPicker(anchor, onPick)
    if not picker then BuildPicker() end

    local items = { { name = "", label = "|cff999999(none - silent)|r" } }
    for _, n in ipairs(ns.BUILTIN) do items[#items + 1] = { name = n, label = n } end
    for _, n in ipairs(ns.db.custom) do items[#items + 1] = { name = n, label = n .. "  |cff66ccff(custom)|r", custom = true } end

    for i, item in ipairs(items) do
        local row = PickerRow(i)
        row.text:SetText(item.label)
        row:SetScript("OnClick", function() picker.Close(); onPick(item.name) end)
        row:SetScript("OnEnter", function(self)
            if item.name ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(item.name)
                GameTooltip:AddLine("Click to use this sound (it plays once as a preview).", 0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        if item.custom then
            row.del:Show()
            row.del:SetScript("OnClick", function()
                ns.RemoveCustom(item.name)
                picker.Close()
                RefreshAll()
                ns.Print("Removed " .. item.name .. " from your custom list.")
            end)
        else
            row.del:Hide()
        end
        row:Show()
    end
    for i = #items + 1, #pickerRows do pickerRows[i]:Hide() end
    picker.content:SetHeight(#items * 20 + 4)

    picker:ClearAllPoints()
    picker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    catcher:Show()
    picker:Show()
end

------------------------------------------------------------------------
-- The menu itself. BuildPanel fills `parent` and returns a table with Refresh()
------------------------------------------------------------------------
local function BuildPanel(parent)
    local p = {}
    p.weapon = "GUN"

    Label(parent, "Hunter Weapon Sounds", 16, -16, "GameFontNormalLarge")

    -- general options ---------------------------------------------------
    local cbEnabled = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cbEnabled:SetPoint("TOPLEFT", 12, -42)
    cbEnabled:SetSize(26, 26)
    Label(parent, "Enabled", 40, -47)
    cbEnabled:SetScript("OnClick", function(self)
        ns.db.enabled = self:GetChecked() and true or false
        ns.ApplyMute()
    end)

    local cbMute = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cbMute:SetPoint("TOPLEFT", 120, -42)
    cbMute:SetSize(26, 26)
    Label(parent, "Mute the game's own gun/bow/crossbow sounds", 148, -47)
    cbMute:SetScript("OnClick", function(self)
        ns.db.mute = self:GetChecked() and true or false
        ns.ApplyMute()
    end)

    local channelBtn = Button(parent, "", 150, 22)
    channelBtn:SetPoint("TOPRIGHT", -16, -44)
    channelBtn:SetScript("OnClick", function()
        local cur = 1
        for i, c in ipairs(ns.CHANNELS) do if c == ns.db.channel then cur = i end end
        ns.db.channel = ns.CHANNELS[(cur % #ns.CHANNELS) + 1]
        RefreshAll()
    end)
    channelBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Sound channel")
        GameTooltip:AddLine("Click to cycle. SFX follows your Sound Effects volume; Master plays even if effects are turned down.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    channelBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local cbTransmog = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cbTransmog:SetPoint("TOPLEFT", 12, -66)
    cbTransmog:SetSize(26, 26)
    Label(parent, "Follow transmog (sounds match how the weapon looks)", 40, -71)
    cbTransmog:SetScript("OnClick", function(self)
        ns.db.useTransmog = self:GetChecked() and true or false
        ns.InvalidateDetectCache()
    end)

    local typeBtn = Button(parent, "", 150, 22)
    typeBtn:SetPoint("TOPRIGHT", -16, -68)
    local TYPE_CYCLE = { "AUTO", "GUN", "BOW", "CROSSBOW" }
    typeBtn:SetScript("OnClick", function()
        local cur = 1
        for i, c in ipairs(TYPE_CYCLE) do if c == ns.db.forceType then cur = i end end
        ns.db.forceType = TYPE_CYCLE[(cur % #TYPE_CYCLE) + 1]
        ns.InvalidateDetectCache()
        RefreshAll()
    end)
    typeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Weapon type")
        GameTooltip:AddLine("Auto detects your weapon (and its transmog look). Click to force Gun, Bow or Crossbow sounds if detection is ever wrong. Type /hws detect to see what the addon sees.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    typeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local cbMinimap = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cbMinimap:SetPoint("TOPLEFT", 12, -90)
    cbMinimap:SetSize(26, 26)
    Label(parent, "Show minimap button", 40, -95)
    cbMinimap:SetScript("OnClick", function(self)
        ns.db.minimap.hide = not self:GetChecked()
        ns.UpdateMinimapButton()
    end)

    -- weapon tabs -------------------------------------------------------
    local tabs = {}
    for i, w in ipairs(ns.WEAPONS) do
        local t = Button(parent, ns.WEAPON_LABEL[w], 110, 24)
        t:SetPoint("TOPLEFT", 16 + (i - 1) * 114, -130)
        t:SetScript("OnClick", function() p.weapon = w; p.Refresh() end)
        tabs[w] = t
    end
    local currentLabel = Label(parent, "", PANEL_W - 190, -134, "GameFontNormal")

    -- slot rows -----------------------------------------------------------
    local rows = { shoot = {}, reload = {} }
    local function BuildRows(kind, title, topY)
        Label(parent, title, 16, topY, "GameFontNormal")
        for i = 1, 3 do
            local y = topY - 22 - (i - 1) * 28
            Label(parent, kind == "shoot" and ("Shoot " .. i) or ("Reload " .. i), 24, y - 4)
            local edit = EditBox(parent, 270)
            edit:SetPoint("TOPLEFT", 100, y)
            local list = Button(parent, "List", 50)
            list:SetPoint("LEFT", edit, "RIGHT", 8, 0)
            local test = Button(parent, "Play", 50)
            test:SetPoint("LEFT", list, "RIGHT", 4, 0)

            local function Commit()
                local text = edit:GetText() or ""
                ns.SetSlot(p.weapon, kind, i, text)
                edit:ClearFocus()
                if text:match("%S") and not ns.IsBuiltin(text) and not ns.FindCustom(text) then
                    local _, msg = ns.AddCustom(text)
                    ns.Print(msg)
                end
                RefreshAll()
            end
            edit:SetScript("OnEnterPressed", Commit)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); p.Refresh() end)
            edit:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("Sound for this slot")
                GameTooltip:AddLine("Pick from the List, or type a file name from your CustomSounds folder, a game sound ID (number), or a full path. Press Enter to save. Empty = silent.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            edit:SetScript("OnLeave", function() GameTooltip:Hide() end)
            list:SetScript("OnClick", function(self)
                OpenPicker(edit, function(name)
                    ns.SetSlot(p.weapon, kind, i, name)
                    RefreshAll()
                    if name ~= "" then ns.PlayEntry(name) end
                end)
            end)
            test:SetScript("OnClick", function()
                local text = edit:GetText() or ""
                if text:match("%S") then
                    if not ns.PlayEntry(text) then
                        ns.Print("The game could not play '" .. text .. "'. Is the file in the CustomSounds folder? New files need a game restart.")
                    end
                end
            end)
            rows[kind][i] = edit
        end
    end
    BuildRows("shoot", "Shoot sounds (one is picked at random each shot)", -170)
    BuildRows("reload", "Reload sounds (one is picked at random after each shot)", -286)

    -- delay / reset / test ----------------------------------------------
    Label(parent, "Reload plays", 24, -410)
    local delayEdit = EditBox(parent, 44)
    delayEdit:SetPoint("TOPLEFT", 100, -406)
    delayEdit:SetJustifyH("CENTER")
    Label(parent, "seconds after the shot (0 - 3)", 152, -410)
    local function CommitDelay()
        if not ns.SetDelay(p.weapon, delayEdit:GetText()) then
            ns.Print("Enter a number of seconds, for example 0.45")
        end
        delayEdit:ClearFocus()
        p.Refresh()
    end
    delayEdit:SetScript("OnEnterPressed", CommitDelay)
    delayEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); p.Refresh() end)

    local testBtn = Button(parent, "Test shoot + reload", 140)
    testBtn:SetPoint("TOPLEFT", 326, -406)
    testBtn:SetScript("OnClick", function() ns.TestWeapon(p.weapon) end)
    local resetBtn = Button(parent, "Reset to defaults", 110)
    resetBtn:SetPoint("LEFT", testBtn, "RIGHT", 4, 0)
    resetBtn:SetScript("OnClick", function()
        ns.ResetWeapon(p.weapon)
        RefreshAll()
        ns.Print(ns.WEAPON_LABEL[p.weapon] .. " sounds reset to defaults.")
    end)

    -- custom sounds -------------------------------------------------------
    Label(parent, "Add a custom sound", 16, -450, "GameFontNormal")
    local note = Label(parent,
        "1) Copy your .ogg or .mp3 file into  Interface\\AddOns\\HunterWeaponSounds\\CustomSounds\\  and restart the game once.\n" ..
        "2) Type its file name below (for example  mygun.ogg ) or a game sound ID, then press Add.\n" ..
        "3) Pick it for any slot with the List button.",
        24, -472, "GameFontHighlightSmall")
    note:SetWidth(PANEL_W - 48)
    note:SetJustifyH("LEFT")

    local addEdit = EditBox(parent, 310)
    addEdit:SetPoint("TOPLEFT", 26, -522)
    local addBtn = Button(parent, "Add", 60)
    addBtn:SetPoint("LEFT", addEdit, "RIGHT", 8, 0)
    local addTest = Button(parent, "Play", 60)
    addTest:SetPoint("LEFT", addBtn, "RIGHT", 4, 0)
    local status = Label(parent, "", 24, -548, "GameFontHighlightSmall")
    status:SetWidth(PANEL_W - 48)
    status:SetJustifyH("LEFT")

    local function DoAdd()
        local ok, msg = ns.AddCustom(addEdit:GetText())
        status:SetText((ok and "|cff40ff40" or "|cffff6060") .. msg .. "|r")
        if ok then addEdit:SetText("") end
        addEdit:ClearFocus()
        RefreshAll()
    end
    addBtn:SetScript("OnClick", DoAdd)
    addEdit:SetScript("OnEnterPressed", DoAdd)
    addEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    addTest:SetScript("OnClick", function()
        local text = addEdit:GetText() or ""
        if text:match("%S") then
            local ok = ns.PlayEntry(text)
            status:SetText(ok and "|cff40ff40Playing.|r" or "|cffff6060The game could not play that. Check the file name; new files need a game restart.|r")
        end
    end)

    -- refresh -------------------------------------------------------------
    function p.Refresh()
        if not ns.db then return end
        cbEnabled:SetChecked(ns.db.enabled)
        cbMute:SetChecked(ns.db.mute)
        cbTransmog:SetChecked(ns.db.useTransmog)
        cbMinimap:SetChecked(not ns.db.minimap.hide)
        typeBtn:SetText("Weapon type: " .. (ns.db.forceType == "AUTO" and "Auto" or ns.WEAPON_LABEL[ns.db.forceType]))
        channelBtn:SetText("Channel: " .. ns.db.channel)
        for w, t in pairs(tabs) do
            if w == p.weapon then t:Disable() else t:Enable() end
        end
        currentLabel:SetText("Editing: " .. ns.WEAPON_LABEL[p.weapon])
        local cfg = ns.db.weapons[p.weapon]
        for i = 1, 3 do
            rows.shoot[i]:SetText(cfg.shoot[i] or "")
            rows.shoot[i]:SetCursorPosition(0)
            rows.reload[i]:SetText(cfg.reload[i] or "")
            rows.reload[i]:SetCursorPosition(0)
        end
        delayEdit:SetText(string.format("%.2f", cfg.delay or 0.45))
    end

    parent:HookScript("OnShow", function() p.Refresh() end)
    panels[#panels + 1] = p
    return p
end

------------------------------------------------------------------------
-- Copyable report window
------------------------------------------------------------------------
local reportFrame
function ns.ShowReport(text)
    if not reportFrame then
        reportFrame = CreateFrame("Frame", "HunterWeaponSoundsReport", UIParent, "BackdropTemplate")
        reportFrame:SetSize(620, 360)
        reportFrame:SetPoint("CENTER")
        reportFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        reportFrame:SetMovable(true)
        reportFrame:EnableMouse(true)
        reportFrame:SetClampedToScreen(true)
        reportFrame:RegisterForDrag("LeftButton")
        reportFrame:SetScript("OnDragStart", reportFrame.StartMoving)
        reportFrame:SetScript("OnDragStop", reportFrame.StopMovingOrSizing)
        MakeBackdrop(reportFrame, 0.06, 0.06, 0.08, 0.97)
        tinsert(UISpecialFrames, "HunterWeaponSoundsReport")
        Label(reportFrame, "Weapon report - the text is selected: press Ctrl+C to copy it", 14, -14, "GameFontNormal")
        local close = CreateFrame("Button", nil, reportFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        close:SetFrameLevel(reportFrame:GetFrameLevel() + 20)
        close:SetScript("OnClick", function() reportFrame:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, reportFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -42)
        scroll:SetPoint("BOTTOMRIGHT", -34, 14)
        local eb = CreateFrame("EditBox", nil, scroll)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(560)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); reportFrame:Hide() end)
        scroll:SetScrollChild(eb)
        reportFrame.edit = eb
    end
    local eb = reportFrame.edit
    eb:SetText(text or "")
    local _, lines = (text or ""):gsub("\n", "\n")
    eb:SetHeight(math.max(300, (lines + 2) * 14))
    reportFrame:Show()
    eb:SetFocus()
    eb:HighlightText()
end

------------------------------------------------------------------------
-- Standalone window
------------------------------------------------------------------------
local window
local function BuildWindow()
    window = CreateFrame("Frame", "HunterWeaponSoundsWindow", UIParent, "BackdropTemplate")
    window:SetSize(PANEL_W, 580)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    MakeBackdrop(window, 0.06, 0.06, 0.08, 0.96)
    window:Hide()
    tinsert(UISpecialFrames, "HunterWeaponSoundsWindow") -- Esc closes it

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetFrameLevel(window:GetFrameLevel() + 20)
    close:RegisterForClicks("AnyUp")
    close:SetScript("OnClick", function() window:Hide() end) -- do not rely on the template's own handler
    BuildPanel(window)
end

function ns.ToggleWindow()
    if not window then BuildWindow() end
    if window:IsShown() then window:Hide() else window:Show() end
end

------------------------------------------------------------------------
-- Options > AddOns page
------------------------------------------------------------------------
local optionsPanel
function ns.OpenSettings()
    if Settings and Settings.OpenToCategory and ns.category then
        pcall(Settings.OpenToCategory, ns.category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    else
        ns.ToggleWindow()
    end
end

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------
local mm
local function PlaceMinimapButton()
    local angle = math.rad(ns.db.minimap.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 5
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function ns.UpdateMinimapButton()
    if not mm then return end
    if ns.db.minimap.hide then mm:Hide() else mm:Show(); PlaceMinimapButton() end
end

local function BuildMinimapButton()
    mm = CreateFrame("Button", "HunterWeaponSoundsMinimapButton", Minimap)
    mm:SetSize(31, 31)
    mm:SetFrameStrata("MEDIUM")
    mm:SetFrameLevel(8)
    mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mm:RegisterForDrag("LeftButton")

    local icon = mm:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\Ability_Marksmanship")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local border = mm:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local hl = mm:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD") -- without this the highlight draws as a solid black disc

    mm:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.db.enabled = not ns.db.enabled
            ns.ApplyMute()
            RefreshAll()
            ns.Print(ns.db.enabled and "enabled" or "disabled (default sounds restored)")
        else
            ns.ToggleWindow()
        end
    end)
    mm:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            px, py = px / s, py / s
            ns.db.minimap.angle = math.deg((math.atan2 or math.atan)(py - my, px - mx))
            PlaceMinimapButton()
        end)
    end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Hunter Weapon Sounds")
        GameTooltip:AddLine("Left-click: open menu", 1, 1, 1)
        GameTooltip:AddLine("Right-click: turn on/off", 1, 1, 1)
        GameTooltip:AddLine("Drag: move button", 1, 1, 1)
        GameTooltip:Show()
    end)
    mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.UpdateMinimapButton()
end

------------------------------------------------------------------------
-- Called by the core once saved settings are loaded
------------------------------------------------------------------------
function ns.InitOptions()
    optionsPanel = CreateFrame("Frame", "HunterWeaponSoundsOptions")
    optionsPanel.name = "Hunter Weapon Sounds"
    BuildPanel(optionsPanel)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        Settings.RegisterAddOnCategory(category)
        ns.category = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end

    BuildMinimapButton()
end

-- Retail: entry in the minimap "Addons" menu (declared in the .toc)
function HunterWeaponSounds_OnCompartmentClick()
    if ns.ToggleWindow then ns.ToggleWindow() end
end
