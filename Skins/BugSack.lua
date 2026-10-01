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
    end

    local tabs = {}
    for _, name in ipairs(TAB_NAMES) do tabs[#tabs + 1] = _G[name] end
    ns.SkinTabRow(S, tabs)
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
