-------------------------------------------------------------------------------
--  Auctionator (retail AH): its four tabs on the auction house (Shopping,
--  Selling, Cancelling, Auctionator) with their content, the shopping/buy
--  dialogs and Auctionator's own popups.
--
--  Auctionator builds its AH UI on the first AH visit: the tab container's
--  OnLoad creates the tab frames + LibAHTab tab buttons, the buy frames follow
--  right after, then the default tab is shown. So:
--   - XML mixins are copied onto frames at creation, and every AH frame is
--     created after login, so post-hooks on the mixin tables (installed in
--     the skin callback) reach every instance: tab container, results
--     listings, and the shared option widgets (inputs, dropdowns, checkboxes).
--   - Each tab frame's content is skinned on its OnShow, by when the
--     Lua-built parts (list scroll bars, buy frames) exist. Primitives are
--     idempotent; the few layout writes are guarded to run once.
--  Item rows, icons and radio buttons stay stock content.
-------------------------------------------------------------------------------
local _, ns = ...
if not ns.RegisterAddonSkin then return end

local function Btn(S, button)
    if not button then return end
    S.Button(button)
    S.StateButtonLabel(button)
end

local function IsPanelButton(frame)
    return frame:IsObjectType("Button") and frame.Left and frame.Middle and frame.Right and true or false
end

-- InputBoxTemplate / LargeInputBoxTemplate / money boxes. Some templates name their box art
-- <name>Left/Middle/Right instead of keying it, which S.EditBox's keyed fade misses.
local function Box(S, editBox)
    if not editBox then return end
    S.EditBox(editBox)
    local name = editBox:GetName()
    if name then
        for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
            local tex = _G[name .. suffix]
            if tex and tex.SetAlpha then tex:SetAlpha(0) end
        end
    end
    -- SearchBoxTemplate's magnifier is a region of the box, faded along with the art
    if editBox.searchIcon then editBox.searchIcon:SetAlpha(1) end
end

local function FadeTree(S, frame, keep)
    if keep[frame] then return end
    S.FadeRegions(frame)
    for _, child in ipairs({ frame:GetChildren() }) do FadeTree(S, child, keep) end
end

-- Auctionator's lists use WowTrimScrollBar, whose trough and stepper caps sit on child frames
-- S.ScrollBar never reaches (it handles MinimalScrollBar's flat layout), so fade the whole tree
-- after it. The thumb is kept: it carries the house thumb strip S.ScrollBar paints.
local function ScrollBar(S, scrollBar)
    if not scrollBar then return end
    S.ScrollBar(scrollBar)
    local keep = {}
    local thumb = (scrollBar.Track and scrollBar.Track.Thumb) or (scrollBar.GetThumb and scrollBar:GetThumb())
    if thumb then keep[thumb] = true end
    FadeTree(S, scrollBar, keep)
end

-- AuctionatorInset(Dark)Template: AH background atlas + inset NineSlice -> flat nested panel
local function Inset(S, inset)
    if not inset then return end
    if inset.NineSlice then S.FadeNineSlice(inset.NineSlice) end
    S.Panel(inset, { inset = true })
end

-- Free-floating panels: SimplePanel dialogs (.Border NineSlice), confirmation dialogs and
-- Auctionator.Dialogs popups (.NineSlice). Direct child buttons/inputs are the dialog's own.
local function Popup(S, frame)
    if not frame then return end
    if frame.Border and frame.Border.SetAlpha then S.FadeNineSlice(frame.Border) end
    if frame.NineSlice then S.FadeNineSlice(frame.NineSlice) end
    S.Panel(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if IsPanelButton(child) then
            Btn(S, child)
        elseif child:IsObjectType("EditBox") then
            Box(S, child)
        end
    end
    if frame.CloseDialog then S.CloseButton(frame.CloseDialog) end
    if frame.Inset then Inset(S, frame.Inset) end
    if frame.ScrollBar then ScrollBar(S, frame.ScrollBar) end
end

-- The anonymous RefreshButtonTemplate (square icon button) of the buy/sell/cancel views
local function RefreshButtons(S, parent)
    if not parent then return end
    for _, child in ipairs({ parent:GetChildren() }) do
        if child:IsObjectType("Button") and child.Icon and not child:GetText() then
            S.Button(child, { "Icon" })
        end
    end
end

local function Listing(S, listing)
    if not listing then return end
    ScrollBar(S, listing.ScrollArea and listing.ScrollArea.ScrollBar)
    if not listing.HeaderContainer then return end
    S.SortHeaderBar(listing)
    -- the sort direction arrow is a region of the column header, faded with its art
    for _, column in ipairs({ listing.HeaderContainer:GetChildren() }) do
        if column.Arrow then column.Arrow:SetAlpha(1) end
    end
end

-------------------------------------------------------------------------------
--  Tab rows
-------------------------------------------------------------------------------
-- One physical pixel in the region's own coordinate space, the seam EUI puts between flat tabs
local function OnePixel(region)
    local _, height = GetPhysicalScreenSize()
    local scale = region:GetEffectiveScale()
    if not height or height <= 0 or not scale or scale < 0.1 or scale > 10 then return 1 end
    return 768 / height / scale
end

-- Matches EUI's own tab rows: 2px shorter (once), chained edge to edge with a 1px seam
local laidOut = {}
local function LayoutTab(tab, previous)
    if laidOut[tab] then return end
    laidOut[tab] = true
    local height = tab:GetHeight()
    if height and height > 2 then tab:SetHeight(height - 2) end
    if previous then
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", previous, "RIGHT", OnePixel(tab), 0)
    end
end

-- Auctionator's in-tab mini tabs; their selection runs through PanelTemplates, which EUI tracks
local function MiniTabs(S, tabs)
    local previous
    for _, tab in ipairs(tabs) do
        S.Tab(tab)
        LayoutTab(tab, previous)
        previous = tab
    end
end

-------------------------------------------------------------------------------
--  Tab content
-------------------------------------------------------------------------------
local function SkinBuyItem(S, frame)
    if not frame then return end
    Btn(S, frame.BackButton)
    RefreshButtons(S, frame)
    Listing(S, frame.ResultsListing)
    Inset(S, frame.Inset)
    Popup(S, frame.BuyDialog)
end

local function SkinBuyCommodity(S, frame)
    if not frame then return end
    Btn(S, frame.BackButton)
    RefreshButtons(S, frame)
    local details = frame.DetailsContainer
    if details then
        Box(S, details.Quantity)
        Btn(S, details.BuyButton)
    end
    Listing(S, frame.ResultsListing)
    Inset(S, frame.Inset)
    Popup(S, frame.WidePriceRangeWarningDialog)
    Popup(S, frame.FinalConfirmationDialog)
    Popup(S, frame.QuantityCheckConfirmationDialog)
end

-- Add/edit item dialog: a ButtonFrameTemplate window over the AH
local function SkinItemDialog(S, frame)
    if not frame then return end
    S.Shell(frame)
    if frame.CloseButton then S.CloseButton(frame.CloseButton) end
    if frame.Inset then S.Inset(frame.Inset) end
    local search = frame.SearchContainer
    if search then
        Box(S, search.SearchString)
        if search.IsExact then
            S.Checkbox(search.IsExact)
            if search.IsExact.Text then S.White(search.IsExact.Text) end
        end
    end
    for _, key in ipairs({ "Finished", "Cancel", "ResetAllButton" }) do Btn(S, frame[key]) end
end

local function SkinShopping(S, frame)
    local options = frame.SearchOptions
    if options then
        Box(S, options.SearchString)
        for _, key in ipairs({ "SearchButton", "MoreButton", "AddToListButton" }) do Btn(S, options[key]) end
    end
    for _, container in ipairs({ frame.ListsContainer, frame.RecentsContainer }) do
        if container then
            Inset(S, container.Inset)
            ScrollBar(S, container.ScrollBar)
        end
    end
    if frame.ContainerTabs then
        MiniTabs(S, { frame.ContainerTabs.ListsTab, frame.ContainerTabs.RecentsTab })
    end
    for _, key in ipairs({ "NewListButton", "ExportButton", "ImportButton", "ExportCSV" }) do Btn(S, frame[key]) end
    Listing(S, frame.ResultsListing)
    Inset(S, frame.ShoppingResultsInset)

    SkinItemDialog(S, _G.AuctionatorShoppingTabItemFrame)
    local exportList = _G.AuctionatorExportListFrame
    Popup(S, exportList)
    Popup(S, exportList and exportList.copyTextDialog)
    Popup(S, _G.AuctionatorImportListFrame)
    Popup(S, frame.exportCSVDialog)
    local history = _G.AuctionatorItemHistoryFrame
    if history then
        Popup(S, history)
        -- the dock button's arrow is its content, not template art
        if history.Dock then S.Button(history.Dock, { "Arrow" }) end
        Listing(S, history.ResultsListing)
    end

    SkinBuyItem(S, _G.AuctionatorBuyItemFrame)
    SkinBuyCommodity(S, _G.AuctionatorBuyCommodityFrame)
end

local function SkinSelling(S, frame)
    local sale = frame.SaleItemFrame
    if sale then
        for _, key in ipairs({ "MaxButton", "PostButton", "SkipButton", "PrevButton" }) do Btn(S, sale[key]) end
        RefreshButtons(S, sale)
    end
    local bagView = frame.BagListing and frame.BagListing.View
    if bagView then ScrollBar(S, bagView.ScrollBar) end
    for _, key in ipairs({ "BagInset", "HistoricalPriceInset", "CurrentPricesInset" }) do Inset(S, frame[key]) end
    for _, key in ipairs({ "CurrentPricesListing", "HistoricalPriceListing", "PostingHistoryListing" }) do
        Listing(S, frame[key])
    end
    local prices = frame.PricesTabsContainer
    if prices then
        MiniTabs(S, { prices.CurrentPricesTab, prices.PriceHistoryTab, prices.YourHistoryTab })
    end
end

local function SkinCancelling(S, frame)
    Box(S, frame.SearchFilter)
    RefreshButtons(S, frame)
    Listing(S, frame.ResultsListing)
    Inset(S, frame.HistoricalPriceInset)
    local undercut = frame.UndercutScanContainer
    if undercut then
        Btn(S, undercut.CancelNextButton)
        Btn(S, undercut.StartScanButton)
    end
end

-- The info page is itself an inset (Bg + NineSlice). Only those two go: a full S.Inset would
-- also fade the content backdrop below, which is a region of this frame too.
local function SkinConfig(S, frame)
    if frame.Bg then frame.Bg:SetAlpha(0) end
    if frame.NineSlice then S.FadeNineSlice(frame.NineSlice) end
    Btn(S, frame.ScanButton)
    Btn(S, frame.OptionsButton)
end

local TAB_SKINS = {
    AuctionatorShoppingFrame = SkinShopping,
    AuctionatorSellingFrame = SkinSelling,
    AuctionatorCancellingFrame = SkinCancelling,
    AuctionatorConfigFrame = SkinConfig,
}

-------------------------------------------------------------------------------
--  The AH tab buttons (LibAHTab)
-------------------------------------------------------------------------------
-- LibAHTab selects its tabs through PanelTemplates, outside the AH's displayMode, which EUI's AH
-- skin reads to light the Blizzard tabs. Selection is therefore driven from the tab frames'
-- visibility. Older EUI builds also kept the last Blizzard tab lit while the AH has no
-- display mode, so the Blizzard tabs are unlit here while one of ours is open; picking a Blizzard
-- tab sets a display mode again, and EUI then lights it on its own. IsShown, not IsVisible:
-- closing the AH keeps the open tab selected.
local function SyncTabSelection(S, tabs)
    if not S.SetTabSelection then return end -- apiVersion 2
    local anyOpen = false
    for _, tab in ipairs(tabs) do
        local open = tab.frameRef and tab.frameRef:IsShown() or false
        S.SetTabSelection(tab, open)
        if open then anyOpen = true end
    end
    if anyOpen and AuctionHouseFrame and AuctionHouseFrame.Tabs then
        for _, blizzardTab in ipairs(AuctionHouseFrame.Tabs) do S.SetTabSelection(blizzardTab, false) end
    end
end

local function LastShownBlizzardTab()
    local blizzardTabs = AuctionHouseFrame and AuctionHouseFrame.Tabs
    if not blizzardTabs then return end
    for i = #blizzardTabs, 1, -1 do
        if blizzardTabs[i]:IsShown() then return blizzardTabs[i] end
    end
end

-- EUI's AH skin draws Blizzard's view layout onto the window (the search-row seam, the category
-- rail's divider and a faint wash, or the sell tab's split) and switches it by the AH's display
-- mode, which stays empty while a LibAHTab tab is open, so the last Blizzard layout keeps showing
-- through Auctionator's content. Each tab frame therefore carries a house-panel backdrop over the
-- whole content area, between the shell's top bar and the seam above the money row, anchored to
-- the AH window so it covers that area whatever the tab frame's own size. It lives on a child
-- frame of the tab, which shows and hides it with its tab, pinned one frame level above the AH
-- window, where EUI's lines sit. The tab frame itself is not enough: the info tab inherits
-- AuctionatorInsetTemplate's useParentLevel, so it shares the AH window's level, and within one
-- level EUI's ARTWORK lines draw over any BACKGROUND region. Higher than +1 would bury the
-- other tabs' insets (also useParentLevel, so at tab level = AH window + 1); at the same level
-- their panel fill (BACKGROUND -6) still draws over this backdrop (-8).
local backdrops = {}
local function ContentBackdrop(S, frame)
    if backdrops[frame] or not AuctionHouseFrame then return end
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetFrameLevel(AuctionHouseFrame:GetFrameLevel() + 1)
    holder:SetAllPoints(AuctionHouseFrame)
    local backdrop = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    backdrop:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 0, -25)
    backdrop:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", 0, 30 + OnePixel(frame))
    backdrop:SetColorTexture(S.GetPanelColor())
    backdrops[frame] = backdrop
end

local hookedTabFrames = {}
local function SetupMainTabs(S, container)
    local tabs = container and container.Tabs
    if not tabs then return end
    for _, tab in ipairs(tabs) do
        S.Tab(tab)
        -- LibAHTab chains every tab to the one before it (another addon's lib tab, maybe), the first
        -- one to a holder frame sitting on the last Blizzard tab; chain that one to the tab directly
        local _, relativeTo = tab:GetPoint(1)
        local previous = relativeTo
        if relativeTo == tab:GetParent() then previous = LastShownBlizzardTab() end
        LayoutTab(tab, previous)

        local frame = tab.frameRef
        if frame and not hookedTabFrames[frame] then
            hookedTabFrames[frame] = true
            ContentBackdrop(S, frame)
            local skinContent = TAB_SKINS[frame:GetName() or ""]
            frame:HookScript("OnShow", ns.Safe(function(self)
                SyncTabSelection(S, tabs)
                if skinContent then skinContent(S, self) end
            end))
            frame:HookScript("OnHide", ns.Safe(function() SyncTabSelection(S, tabs) end))
            if skinContent and frame:IsShown() then skinContent(S, frame) end
        end
    end
    SyncTabSelection(S, tabs)
end

-------------------------------------------------------------------------------
--  Registration
-------------------------------------------------------------------------------
local function HookMixin(mixinName, method, fn)
    local mixin = _G[mixinName]
    if type(mixin) == "table" and type(mixin[method]) == "function" then
        ns.SafeHook(mixin, method, fn)
    end
end

ns.RegisterAddonSkin("Auctionator", function(S)
    -- Shared option widgets, wherever Auctionator places them (tabs, item dialog, export list)
    HookMixin("AuctionatorConfigCheckboxMixin", "OnLoad", function(self)
        local checkbox = self.CheckBox
        if not checkbox then return end
        S.Checkbox(checkbox)
        if checkbox.Label then S.White(checkbox.Label) end
    end)
    for _, mixinName in ipairs({ "AuctionatorConfigNumericInputMixin", "AuctionatorConfigTextInputMixin",
                                 "AuctionatorConfigurationCopyAndPasteMixin" }) do
        HookMixin(mixinName, "OnLoad", function(self) Box(S, self.InputBox) end)
    end
    HookMixin("AuctionatorConfigMinMaxMixin", "OnLoad", function(self)
        Box(S, self.MinBox)
        Box(S, self.MaxBox)
    end)
    HookMixin("AuctionatorConfigMoneyInputMixin", "OnLoad", function(self)
        local money = self.MoneyInput
        if not money then return end
        Box(S, money.GoldBox)
        Box(S, money.SilverBox)
        Box(S, money.CopperBox)
    end)
    -- AuctionatorDropDown wraps the real dropdown; the filter key selector creates it in OnLoad
    for _, mixinName in ipairs({ "AuctionatorDropDownMixin", "AuctionatorFilterKeySelectorMixin" }) do
        HookMixin(mixinName, "OnLoad", function(self)
            if self.DropDown then S.Dropdown(self.DropDown) end
        end)
    end
    -- the small square "x" reset buttons; their icon is the .texture region
    HookMixin("AuctionatorResetButtonMixin", "OnLoad", function(self) S.Button(self, { "texture" }) end)

    -- Results listings: columns are (re)built by InitializeTable and resized when columns hide
    for _, method in ipairs({ "InitializeTable", "UpdateDimensionsForHiding", "OnShow" }) do
        HookMixin("AuctionatorResultsListingMixin", method, function(self) Listing(S, self) end)
    end

    HookMixin("AuctionatorTabContainerMixin", "OnLoad", function(self) SetupMainTabs(S, self) end)
    S.OnLooksChanged(function()
        for _, backdrop in pairs(backdrops) do backdrop:SetColorTexture(S.GetPanelColor()) end
    end)
    -- the AH was already visited this session (skinning turned on live)
    SetupMainTabs(S, _G.AuctionatorAHTabsContainer)

    -- Auctionator.Dialogs popups: AuctionatorDialog1..n, created on first use
    local dialogs = Auctionator and Auctionator.Dialogs
    if dialogs then
        local function SkinDialogs()
            local i = 1
            while _G["AuctionatorDialog" .. i] do
                Popup(S, _G["AuctionatorDialog" .. i])
                i = i + 1
            end
        end
        for _, method in ipairs({ "ShowEditBox", "ShowConfirm", "ShowConfirmAlt", "ShowMoney" }) do
            if type(dialogs[method]) == "function" then ns.SafeHook(dialogs, method, SkinDialogs) end
        end
    end
end)
