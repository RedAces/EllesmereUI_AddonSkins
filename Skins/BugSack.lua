-------------------------------------------------------------------------------
--  BugSack: the sack window (BugSackFrame) with its title-bar search box,
--  error text, prev/send/next buttons, the session tabs and the Options tab
--  (checkboxes, dropdowns and the wipe button).
--
--  BugSack builds the window on the first BugSack:OpenSack() or
--  BugSack:OpenConfig() and shows it right away, so the skin runs after both
--  (idempotent primitives, once-only layout). The text area stays BugSack's
--  own: it is the content.
-------------------------------------------------------------------------------
local _, ns = ...
if not ns.RegisterAddonSkin then return end

local TAB_NAMES = { "BugSackTabAll", "BugSackTabSession", "BugSackTabLast", "BugSackTabOptions" }

local function Btn(S, button)
    if not button then return end
    S.Button(button)
    S.StateButtonLabel(button) -- prev/next/send disable at the ends of the list
end

-- BugSack seats its title texts 40px in, clear of the portrait; the shell has none, so they
-- move to the shell's own edge padding. Every point on the title bar's left side at that 40px
-- inset is shifted (session label, and the filter label the search box hangs off). Once.
local TITLE_INSET, TITLE_PADDING = 40, 8
local titleShifted = false
local function UnindentTitle(titleBar)
    if titleShifted then return end
    titleShifted = true
    local items = { titleBar:GetChildren() }
    for _, region in ipairs({ titleBar:GetRegions() }) do items[#items + 1] = region end
    for _, item in ipairs(items) do
        local points, shift = {}, false
        for i = 1, item:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = item:GetPoint(i)
            if relativeTo == titleBar and point:find("LEFT") and x == TITLE_INSET then
                x = TITLE_PADDING
                shift = true
            end
            points[i] = { point, relativeTo, relativePoint, x, y }
        end
        if shift then
            item:ClearAllPoints()
            for _, p in ipairs(points) do item:SetPoint(unpack(p)) end
        end
    end
end

-- The checkboxes are 26px frames whose visible box is inset 4px, so the border goes on that inset
-- too (else a second square frames the box) and the label moves out by the same 4px plus a gap. Once.
local CHECK_INSET, LABEL_GAP = 4, 4
local spacedChecks = setmetatable({}, { __mode = "k" })
local function SkinCheckbox(S, check)
    S.Checkbox(check, { borderInset = CHECK_INSET })
    local label = check.Text
    if spacedChecks[check] or not label or label:GetNumPoints() ~= 1 then return end
    local point, relativeTo, relativePoint, x, y = label:GetPoint(1)
    if relativeTo ~= check or not point:find("LEFT") then return end
    spacedChecks[check] = true
    label:ClearAllPoints()
    label:SetPoint(point, relativeTo, relativePoint, (x or 0) + LABEL_GAP, y or 0)
    -- keep the label clickable like BugSack does, over its new spot
    check:SetHitRectInsets(0, -label:GetStringWidth() - 4 - LABEL_GAP, 0, 0)
end

-- DropdownButtonMixin's SetupMenu identifies the modern dropdown regardless of its object type
local function IsDropdown(frame)
    return frame:IsObjectType("DropdownButton") or type(frame.SetupMenu) == "function"
end

-- The options panel is unnamed: it is the window child laid over the text's scroll frame.
-- Its checkboxes sit directly on it, the dropdowns one level down inside label rows.
local function SkinOptionWidgets(S, frame, depth)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType("CheckButton") then
            SkinCheckbox(S, child)
        elseif IsDropdown(child) then
            S.Dropdown(child)
        elseif depth < 2 then
            SkinOptionWidgets(S, child, depth + 1)
        end
    end
end

local function SkinOptions(S, window, scrollFrame)
    if not scrollFrame then return end
    for _, child in ipairs({ window:GetChildren() }) do
        if child ~= scrollFrame and not child:GetName() and child:GetNumPoints() > 0 then
            local _, relativeTo = child:GetPoint(1)
            if relativeTo == scrollFrame then SkinOptionWidgets(S, child, 1) end
        end
    end
end

local function SkinSack(S)
    local window = _G.BugSackFrame
    if not window then return end

    -- PortraitFrameTemplate: S.Shell takes the frame's own art, the NineSlice border (HeldBagLayout)
    -- and the portrait sit on child frames
    S.Shell(window)
    if window.NineSlice then S.FadeNineSlice(window.NineSlice) end
    if window.PortraitContainer then S.FadeRegions(window.PortraitContainer) end
    if window.CloseButton then S.CloseButton(window.CloseButton) end

    Btn(S, _G.BugSackPrevButton)
    Btn(S, _G.BugSackSendButton)
    Btn(S, _G.BugSackNextButton)
    Btn(S, _G.BugSackWipeButton) -- disabled while the sack is empty

    local text = _G.BugSackScrollText
    local scrollFrame = text and text:GetParent()
    if scrollFrame then ns.SkinScrollBar(S, scrollFrame.ScrollBar) end
    SkinOptions(S, window, scrollFrame)

    -- the filter box (double-click the title) is the only edit box on the title bar
    local titleBar = window.TitleContainer
    if titleBar then
        for _, child in ipairs({ titleBar:GetChildren() }) do
            if child:IsObjectType("EditBox") then S.EditBox(child) end
        end
        UnindentTitle(titleBar)
    end

    local tabs = {}
    for _, name in ipairs(TAB_NAMES) do tabs[#tabs + 1] = _G[name] end
    ns.SkinTabRow(S, tabs)
    -- the tab template caps the width; the house label needs more room
    for _, tab in ipairs(tabs) do ns.WidenTab(tab) end
end

ns.RegisterAddonSkin("BugSack", function(S)
    -- BugSack selects tabs with PanelTemplates_SelectTab/DeselectTab directly, which EUI only picks
    -- up after a click, so a search (it deselects every tab) left the old tab lit. Mirror both into
    -- the tab visuals instead.
    local isSackTab = {}
    for _, name in ipairs(TAB_NAMES) do isSackTab[name] = true end
    if S.SetTabSelection then -- apiVersion 2
        local function Mirror(selected)
            return function(tab)
                local name = tab and tab.GetName and tab:GetName()
                if name and isSackTab[name] then S.SetTabSelection(tab, selected) end
            end
        end
        hooksecurefunc("PanelTemplates_SelectTab", ns.Safe(Mirror(true)))
        hooksecurefunc("PanelTemplates_DeselectTab", ns.Safe(Mirror(false)))
    end

    local BugSack = _G.BugSack
    if BugSack then
        -- OpenConfig (right-click on the minimap icon) opens the window straight on the Options tab
        for _, method in ipairs({ "OpenSack", "OpenConfig" }) do
            if type(BugSack[method]) == "function" then
                ns.SafeHook(BugSack, method, function() SkinSack(S) end)
            end
        end
    end
    -- the sack was already opened this session (skinning turned on live)
    SkinSack(S)
end)
