local ADDON_NAME, ns = ...
local UI = {}
ns.UI = UI

local W       = 420
local TITLE_H = 22
local ROW_H   = 22
local ICON_S  = 16
local PAD     = 6

local C = {
    frameBg         = {0.06, 0.06, 0.09, 0.93},
    frameBorder     = {0.22, 0.22, 0.22, 1},
    titleBarBg      = {0.05, 0.05, 0.20, 1},
    divider         = {0.4,  0.4,  0.55, 0.55},
    upgradeTint     = {0,    0.45, 0,    0.18},
    askBtnBg        = {0.12, 0.25, 0.45, 0.90},
    askBtnHighlight = {1,    1,    1,    0.15},
    -- hex escape sequences for font strings
    gold   = "ffd700",
    ask    = "aaddff",
    sent   = "44aa44",
    dim    = "888888",
    danger = "dd2222",
}

local mainFrame, scrollFrame, content
local rows     = {}
local contentH = 0

local function Build()
    mainFrame = CreateFrame("Frame", ADDON_NAME .. "LootLog", UIParent, "BackdropTemplate")
    mainFrame:SetWidth(W)
    mainFrame:SetHeight(TITLE_H + PAD * 2 + ROW_H * 8 + 2)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
    mainFrame:SetMovable(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    mainFrame:SetBackdropColor(unpack(C.frameBg))
    mainFrame:SetBackdropBorderColor(unpack(C.frameBorder))
    mainFrame:SetResizable(true)
    mainFrame:SetResizeBounds(240, TITLE_H + PAD * 2 + ROW_H * 3 + 14)
    mainFrame:SetScript("OnSizeChanged", function(_, w)
        if content then content:SetWidth(w - PAD * 2) end
    end)
    mainFrame:Hide()

    -- Title bar
    local titleBg = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -5)
    titleBg:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",   1, -1)
    titleBg:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(TITLE_H - 2)
    titleBg:SetColorTexture(unpack(C.titleBarBg))

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", mainFrame, "TOPLEFT", PAD + 2, -(TITLE_H * 0.5))
    title:SetText("|cff" .. C.gold .. ns.DISPLAY_NAME .. "|r")

    local div = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -4)
    div:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",   4, -TITLE_H)
    div:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT",  -4, -TITLE_H)
    div:SetHeight(1)
    div:SetColorTexture(unpack(C.divider))

    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() mainFrame:Hide() end)

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", ADDON_NAME .. "LootScroll", mainFrame)
    scrollFrame:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     PAD, -(TITLE_H + PAD))
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PAD, PAD + 12)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur   = self:GetVerticalScroll()
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(cur - delta * ROW_H * 2, range)))
    end)

    local grip = CreateFrame("Button", nil, mainFrame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -1, 1)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() mainFrame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp",   function() mainFrame:StopMovingOrSizing() end)

    content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(W - PAD * 2)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
end

local function ScrollToBottom()
    C_Timer.After(0, function()
        if scrollFrame then
            scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
        end
    end)
end

-- Small "Ask" button that sends the whisper on click, then collapses to "sent"
local function MakeAskButton(row, itemLink, playerName)
    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(34, 16)
    btn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(unpack(C.askBtnBg))

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(unpack(C.askBtnHighlight))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", btn)
    label:SetText("|cff" .. C.ask .. ns.L.ASK_BUTTON .. "|r")

    btn:SetScript("OnClick", function(self)
        local db  = ns.addon.db.profile
        local msg = (db.whisperTemplate or ns.L.WHISPER_TEMPLATE):gsub("%%item", itemLink)
        C_ChatInfo.SendChatMessage(msg, "WHISPER", nil, playerName)
        self:Hide()
        local sent = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sent:SetPoint("RIGHT", row, "RIGHT", -3, 0)
        sent:SetText("|cff" .. C.sent .. ns.L.SENT .. "|r")
    end)
end

-- wasWhispered:        true when Tracker already sent the auto-whisper
-- looterEquippedLevel: ilvl the looter has in that slot (nil = unknown, 0 = empty)
function UI:AddLootEntry(playerName, itemLink, isUpgrade, isSelf, wasWhispered, looterEquippedLevel)
    if not mainFrame then Build() end

    local _, _, _, itemLevel, _, _, _, _, _, texture = C_Item.GetItemInfo(itemLink)
    texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"

    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -contentH)
    row:SetPoint("RIGHT",   content, "RIGHT",   0,  0)

    -- Upgrade: green tint
    if isUpgrade then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(unpack(C.upgradeTint))
    end

    -- Item icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_S, ICON_S)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    icon:SetTexture(texture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Right section layout, right to left:
    --   Non-upgrade:    ilvl:XXX | label
    --   Self upgrade:   ilvl:XXX | yours:XXX | label
    --   Other upgrade:  Ask/sent(-38) | yours:XXX(-58) | their:XXX(-58) | ilvl:XXX(-58) | label
    local COL = 58  -- width per text column
    local showItemIlvl  = itemLevel and itemLevel > 0
    local showLooterIlvl = looterEquippedLevel and looterEquippedLevel > 0

    -- cursor starts at right edge; each placed column shifts it left by COL
    local cursor = -4

    if not isSelf then
        -- Ask / sent at far right
        if wasWhispered then
            local sent = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sent:SetPoint("RIGHT", row, "RIGHT", cursor, 0)
            sent:SetText("|cff" .. C.sent .. ns.L.SENT .. "|r")
        else
            MakeAskButton(row, itemLink, playerName)
        end
        cursor = cursor - 38

        -- yours:XXX
        if showLooterIlvl then
            local yoursFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            yoursFs:SetPoint("RIGHT", row, "RIGHT", cursor, 0)
            yoursFs:SetText(string.format("|cff" .. C.dim .. "%s:%d|r", ns.L.LABEL_YOURS, looterEquippedLevel))
            cursor = cursor - COL
        end

        -- their:XXX
        if showLooterIlvl then
            local theirColor = (itemLevel and looterEquippedLevel < itemLevel) and C.danger or C.dim
            local theirIlvl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            theirIlvl:SetPoint("RIGHT", row, "RIGHT", cursor, 0)
            theirIlvl:SetText(string.format("|cff%s%s:%d|r", theirColor, ns.L.LABEL_THEIR, looterEquippedLevel))
            cursor = cursor - COL
        end
    elseif isUpgrade and isSelf then
        -- yours:XXX (self, always green)
        if showLooterIlvl then
            local yoursFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            yoursFs:SetPoint("RIGHT", row, "RIGHT", cursor, 0)
            yoursFs:SetText(string.format("|cff" .. C.dim .. "%s:%d|r", ns.L.LABEL_YOURS, looterEquippedLevel))
            cursor = cursor - COL
        end
    end

    -- ilvl:XXX (all rows)
    if showItemIlvl then
        local ilvlFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ilvlFs:SetPoint("RIGHT", row, "RIGHT", cursor, 0)
        ilvlFs:SetText(string.format("|cff" .. C.dim .. "%s:%d|r", ns.L.LABEL_ILVL, itemLevel))
        cursor = cursor - COL
    end

    local labelRight = cursor

    -- "Name: [item link]" — truncates if too long
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT",  icon,  "RIGHT",  4, 0)
    label:SetPoint("RIGHT", row,   "RIGHT", labelRight, 0)
    label:SetJustifyH("LEFT")
    label:SetNonSpaceWrap(false)
    local name = isSelf and ("|cff" .. C.gold .. ns.L.LABEL_YOU .. "|r") or playerName
    label:SetText(name .. ": " .. itemLink)

    -- Tooltip only when hovering the icon or item link text
    local hover = CreateFrame("Button", nil, row)
    hover:SetPoint("TOPLEFT",     icon,  "TOPLEFT",  0,  0)
    hover:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, 0)
    hover:SetScript("OnEnter", function(f)
        GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    contentH = contentH + ROW_H
    content:SetHeight(contentH)
    table.insert(rows, row)

    if not mainFrame:IsShown() then mainFrame:Show() end
    ScrollToBottom()
end

function UI:Clear()
    if not mainFrame then return end
    for _, row in ipairs(rows) do
        row:Hide()
        row:SetParent(UIParent)
    end
    rows     = {}
    contentH = 0
    if content then content:SetHeight(1) end
end

function UI:Show()
    if not mainFrame then Build() end
    mainFrame:Show()
end

-- Populates the frame with sample entries covering all row states.
-- Uses the player's equipped items for real item links and tooltips.
function UI:ShowTest()
    self:Clear()

    -- Collect up to 4 equipped item links for realistic tooltips
    local links = {}
    for _, slotId in ipairs({16, 1, 5, 11}) do  -- mainhand, head, chest, ring1
        local link = GetInventoryItemLink("player", slotId)
        if link then links[#links + 1] = link end
    end
    if #links == 0 then
        -- Hearthstone is always in the cache as a last resort
        local hs = "|Hitem:6948:0:0:0:0:0:0:0:0:0:0:0:0|h[Hearthstone]|h|r"
        links = {hs, hs, hs, hs}
    end
    local function L(i) return links[((i - 1) % #links) + 1] end

    local player = UnitName("player")
    self:AddLootEntry("Thrall",   L(1), false, false, false, nil)  -- plain loot
    self:AddLootEntry("Jaina",    L(2), true,  false, true,  285)  -- upgrade, auto-whispered, their:485
    self:AddLootEntry("Sylvanas", L(3), true,  false, false, 289)  -- upgrade, Ask pending, their:462
    self:AddLootEntry(player,     L(4), true,  true,  false, nil)  -- self upgrade
end
