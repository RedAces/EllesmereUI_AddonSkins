-------------------------------------------------------------------------------
--  BugSack: the sack window (BugSackFrame) with its title-bar search box,
--  error text, prev/send/next buttons and the three session tabs below.
--
--  BugSack builds the window on the first BugSack:OpenSack() and shows it
--  right away, so the skin runs after every OpenSack (idempotent primitives,
--  once-only layout). The text area stays BugSack's own: it is the content.
-------------------------------------------------------------------------------
local _, ns = ...
if not ns.RegisterAddonSkin then return end

local TAB_NAMES = { "BugSackTabAll", "BugSackTabSession", "BugSackTabLast" }

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

    local text = _G.BugSackScrollText
    local scrollFrame = text and text:GetParent()
    if scrollFrame then ns.SkinScrollBar(S, scrollFrame.ScrollBar) end

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
    if BugSack and type(BugSack.OpenSack) == "function" then
        ns.SafeHook(BugSack, "OpenSack", function() SkinSack(S) end)
    end
    -- the sack was already opened this session (skinning turned on live)
    SkinSack(S)
end)
