-------------------------------------------------------------------------------
--  CraftSim: its module windows and the widgets in them, plus the
--  "+ CraftQueue" buttons it adds to Blizzard's recipe view.
--
--  CraftSim builds every module UI through its GGUI library (GGUI-2.1) at its
--  own ADDON_LOADED, before EUI hands out skins at login. So the skin works
--  in two passes that share one classifier:
--   - a sweep over what already exists: every GGUI window registers itself
--     in CraftSim.INIT.FRAMES, and the recipe-view buttons hang off
--     CraftSim.CRAFTQ (the addon table comes from CraftSimAPI:GetCraftSim());
--   - post-hooks on the GGUI constructors for everything built later
--     (list rows, popups, lazily created windows). GGUI dispatches `new`
--     through the class table at call time, so a hook on a class also covers
--     its subclasses.
--  Widgets are recognized by their WoW frame, not their GGUI class, so both
--  passes treat them alike. Anything that doesn't match a known shape stays
--  stock: item icons, help/tutorial icons, sliders and list rows. Context
--  menus (e.g. "Sort By") are Blizzard's shared menu system, which EUI's own
--  Blizzard skin styles for every addon, so they are left to EUI.
-------------------------------------------------------------------------------
local _, ns = ...
if not ns.RegisterAddonSkin then return end

-- Textures CraftSim adds to a template button afterwards are its content, e.g. the quality icons
-- on the simulation mode's "all reagents in this quality" header buttons. S.Button fades every
-- region except the ones it is told to keep by key, and these have no key, so they get one here.
local CONTENT_KEY = "EllesmereUI_AddonSkins_Content"
local function ContentKeys(button)
    local art = {}
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if button[key] then art[button[key]] = true end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local texture = button[getter](button)
        if texture then art[texture] = true end
    end
    local keys = {}
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") and not art[region] then
            local key = CONTENT_KEY .. (#keys + 1)
            button[key] = region
            keys[#keys + 1] = key
        end
    end
    return keys
end

local function Btn(S, button)
    S.Button(button, ContentKeys(button))
    S.StateButtonLabel(button)
end

-- UIPanelScrollFrameTemplate's legacy bar (a Slider with arrow buttons): S.ScrollBar only knows
-- MinimalScrollBar. Fade the art and ride a house thumb strip on the faded thumb.
local function LegacyScrollBar(S, bar)
    local thumb = bar.ThumbTexture or (bar.GetThumbTexture and bar:GetThumbTexture())
    S.FadeRegions(bar)
    if bar.ScrollUpButton then S.FadeRegions(bar.ScrollUpButton) end
    if bar.ScrollDownButton then S.FadeRegions(bar.ScrollDownButton) end
    if thumb then
        local strip = bar:CreateTexture(nil, "OVERLAY")
        strip:SetColorTexture(1, 1, 1, 0.3)
        strip:SetWidth(4)
        strip:SetPoint("TOP", thumb, "TOP")
        strip:SetPoint("BOTTOM", thumb, "BOTTOM")
    end
end

-- BlizzardTabSystem selects with PanelTemplates_SelectTab/DeselectTab directly, which EUI only
-- notices after a click, so those calls are mirrored into the tab visuals. Tabs already set up
-- before the skin read their state from the template's active art.
local skinnedTabs = {}
local tabHooks = false
local function Tab(S, tab)
    S.Tab(tab)
    ns.WidenTab(tab)
    skinnedTabs[tab] = true
    if not S.SetTabSelection then return end -- apiVersion 2
    if not tabHooks then
        tabHooks = true
        local function Mirror(selected)
            return ns.Safe(function(t)
                if t and skinnedTabs[t] then S.SetTabSelection(t, selected) end
            end)
        end
        hooksecurefunc("PanelTemplates_SelectTab", Mirror(true))
        hooksecurefunc("PanelTemplates_DeselectTab", Mirror(false))
    end
    if tab.LeftActive then S.SetTabSelection(tab, tab.LeftActive:IsShown() and true or false) end
end

-- GGUI.ToggleButton: red art when on, the same art desaturated when off. Flattened, the state shows
-- as an accent wash plus a white label when on, a gray label when off. The state is read back from
-- the (faded) normal texture's desaturation, which GGUI's SetToggle sets on every toggle, so this
-- also works for toggles built before the skin. Re-synced from a SetToggle hook.
local TOGGLE_ATLAS = "128-RedButton-UP"
local toggleWashes = {}
local function IsToggleButton(button)
    local normal = button:GetNormalTexture()
    return normal and normal.GetAtlas and normal:GetAtlas() == TOGGLE_ATLAS or false
end

local function SyncToggle(button)
    local wash = toggleWashes[button]
    local normal = button:GetNormalTexture()
    if not wash or not normal then return end
    local on = not normal:IsDesaturated()
    wash:SetShown(on)
    local label = button:GetFontString()
    if label then
        if on then label:SetTextColor(1, 1, 1) else label:SetTextColor(0.6, 0.6, 0.6) end
    end
end

local function ToggleButton(S, button)
    S.Button(button, ContentKeys(button))
    local wash = button:CreateTexture(nil, "BORDER")
    wash:SetAllPoints(button)
    local r, g, b = S.GetAccentColor()
    wash:SetColorTexture(r, g, b, 0.25)
    toggleWashes[button] = wash
    SyncToggle(button)
end

-- InputBoxTemplate's art reaches past the edit box, which made its text look inset; the house box
-- fills exactly the edit box, so the text gets that room back as an inset. Once per box.
local INPUT_TEXT_INSET = 4
local function EditBox(S, editBox)
    S.EditBox(editBox)
    local left, right, top, bottom = editBox:GetTextInsets()
    editBox:SetTextInsets((left or 0) + INPUT_TEXT_INSET, (right or 0) + INPUT_TEXT_INSET, top or 0, bottom or 0)
end

-- Legacy UIDropDownMenuTemplate: the frame is much larger than its visible box (transparent caps,
-- 32px tall art), and S.Dropdown fills the whole frame. So the house dropdown look goes on a proxy
-- covering just the visible box (from the art's left edge to the arrow button), at the dropdown's
-- own frame level so its text and icon still draw on top. The proxy takes no mouse input; clicks
-- reach the dropdown's arrow button as before.
local LEGACY_DROPDOWN_LEFT = 16
local function LegacyDropdown(S, dropdown)
    S.FadeRegions(dropdown)
    local name = dropdown:GetName()
    if name then
        for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
            local texture = _G[name .. suffix]
            if texture and texture.SetAlpha then texture:SetAlpha(0) end
        end
    end
    local arrowButton = dropdown.Button
    if arrowButton then S.FadeRegions(arrowButton) end
    local proxy = CreateFrame("Frame", nil, dropdown)
    proxy:SetFrameLevel(dropdown:GetFrameLevel())
    proxy:EnableMouse(false)
    -- the template's arrow button sits 1px below the frame's top edge; the box shares its height
    proxy:SetPoint("TOPLEFT", dropdown, "TOPLEFT", LEGACY_DROPDOWN_LEFT, -1)
    if arrowButton then
        proxy:SetPoint("BOTTOMRIGHT", arrowButton, "BOTTOMRIGHT")
    else
        proxy:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -LEGACY_DROPDOWN_LEFT, 7)
    end
    S.Dropdown(proxy)
    if dropdown.Text then S.White(dropdown.Text) end
end

-- The house checkbox draws its box 4px inside the frame and leaves its label where the template put
-- it, flush against the box. GGUI labels are either the template's own Text or a separate FontString
-- on the checkbox's parent, anchored to the checkbox; both get a gap. Once per label.
local CHECKBOX_LABEL_GAP = 6
local shiftedLabels = setmetatable({}, { __mode = "k" })
local function SpaceCheckboxLabel(checkbox)
    local labels = { checkbox.Text }
    local parent = checkbox:GetParent()
    if parent then
        for _, region in ipairs({ parent:GetRegions() }) do
            if region:IsObjectType("FontString") then labels[#labels + 1] = region end
        end
    end
    for _, label in ipairs(labels) do
        if not shiftedLabels[label] and label:GetNumPoints() == 1 then
            local point, relativeTo, relativePoint, x, y = label:GetPoint(1)
            if relativeTo == checkbox and point:find("LEFT") then
                shiftedLabels[label] = true
                label:ClearAllPoints()
                label:SetPoint(point, relativeTo, relativePoint, (x or 0) + CHECKBOX_LABEL_GAP, y or 0)
            end
        end
    end
end

local function IsFrame(object)
    return type(object) == "table" and type(object.GetObjectType) == "function" and type(object.IsForbidden) == "function"
end

-- Skins one frame by its shape. Returns without touching anything it doesn't recognize.
local seen = setmetatable({}, { __mode = "k" })
local function SkinWidget(S, frame)
    if not IsFrame(frame) or seen[frame] or frame:IsForbidden() then return end
    seen[frame] = true
    local isButton = frame:IsObjectType("Button")
    if frame:IsObjectType("CheckButton") then
        S.Checkbox(frame)
        if frame.Text then S.White(frame.Text) end
        SpaceCheckboxLabel(frame)
    elseif frame:IsObjectType("EditBox") then
        -- InputBoxTemplate (text, numeric and currency inputs); other edit boxes are content
        if frame.Left and frame.Middle and frame.Right then EditBox(S, frame) end
    elseif frame:IsObjectType("DropdownButton") then
        S.Dropdown(frame)
    elseif frame.Track and (frame.Back or frame.Forward) then
        ns.SkinScrollBar(S, frame)
    elseif frame:IsObjectType("Slider") and (frame.ScrollUpButton or frame.ScrollDownButton) then
        LegacyScrollBar(S, frame)
    elseif isButton and (frame.LeftActive or frame.MiddleActive) then
        Tab(S, frame)
    elseif isButton and frame.Left and frame.Middle and frame.Right then
        -- UIPanelButtonTemplate draws with Left/Middle/Right only; any other normal texture means GGUI
        -- gave the button its own art (icons), and a hidden Left a text-only button
        if IsToggleButton(frame) then
            ToggleButton(S, frame)
        elseif not frame:GetNormalTexture() and frame.Left:IsShown() then
            Btn(S, frame)
        end
    elseif frame:GetObjectType() == "Frame" and frame.Button and frame.Text and frame.Left then
        LegacyDropdown(S, frame)
    end
end

local function SkinTree(S, frame, depth)
    if not IsFrame(frame) or frame:IsForbidden() then return end
    depth = depth or 0
    SkinWidget(S, frame)
    if depth >= 12 then return end
    for _, child in ipairs({ frame:GetChildren() }) do SkinTree(S, child, depth + 1) end
end

-- The collapse (minimize) button next to the close button: the API's close button gets the house
-- glyph at 14px, but there is no primitive for a minimize button, so this one is drawn the same
-- way (Blizzard's minimize atlas at 14px, 75% white, full white on hover) over its faded 20px art.
local collapseGlyphs = setmetatable({}, { __mode = "k" })
local function CollapseButton(button)
    if collapseGlyphs[button] then return end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local texture = button[getter](button)
        if texture then texture:SetAlpha(0) end
    end
    local glyph = button:CreateTexture(nil, "OVERLAY")
    glyph:SetAtlas("uitools-icon-minimize")
    glyph:SetSize(14, 14)
    glyph:SetPoint("CENTER", -2, 0)
    glyph:SetVertexColor(1, 1, 1, 0.75)
    collapseGlyphs[button] = glyph
    button:HookScript("OnEnter", function() glyph:SetVertexColor(1, 1, 1, 1) end)
    button:HookScript("OnLeave", function() glyph:SetVertexColor(1, 1, 1, 0.75) end)
end

-- A GGUI.Frame window: CraftSim gives every one of them a backdrop (a tooltip-border box). Titled or
-- closeable ones are windows and get the shell, the rest are boxes and get a panel.
local windows = setmetatable({}, { __mode = "k" })
local function SkinWindow(S, gguiFrame)
    local frame = gguiFrame and gguiFrame.frame
    if not IsFrame(frame) or windows[frame] or not frame.backdropInfo then return end
    windows[frame] = true
    local closeButton = frame.closeButton and frame.closeButton.button
    local title = gguiFrame.title and gguiFrame.title.frame
    if title or closeButton then
        S.Shell(frame)
        -- seat the title on the shell's 25px top bar (GGUI anchors it 15px below the top edge)
        if title and title.ClearAllPoints then
            title:ClearAllPoints()
            title:SetPoint("CENTER", frame, "TOP", 0, -12.5)
        end
        -- close and collapse buttons hang 10px below the top edge; center them on the bar as well,
        -- keeping their horizontal offset
        for _, gguiButton in ipairs({ frame.closeButton, frame.collapseButton }) do
            local button = gguiButton and gguiButton.button
            if button then
                local point, relativeTo, relativePoint, x = button:GetPoint(1)
                if point and relativeTo == frame and point:find("TOP") then
                    button:ClearAllPoints()
                    button:SetPoint(point, relativeTo, relativePoint, x, -(12.5 - button:GetHeight() / 2))
                end
            end
        end
    else
        S.Panel(frame)
    end
    if closeButton then S.CloseButton(closeButton) end
    if frame.collapseButton and frame.collapseButton.button then CollapseButton(frame.collapseButton.button) end
end

-- Some content is built with plain CreateFrame when it is first needed (e.g. the recipe scan's
-- per-profession results with their "Sort By" button), out of reach of the GGUI hooks. Each window
-- is swept again whenever it shows, a frame later so its own OnShow work is done; frames already
-- classified cost one table lookup.
local resweepHooked = setmetatable({}, { __mode = "k" })
local function ResweepOnShow(S, frame)
    if not IsFrame(frame) or resweepHooked[frame] then return end
    resweepHooked[frame] = true
    frame:HookScript("OnShow", function(self)
        C_Timer.After(0, ns.Safe(function() SkinTree(S, self) end))
    end)
end

-- The recipe scan seats its "Scan Professions" button (25px) on top of the profession list, which
-- leaves too little room below the shell's 25px top bar: the button ran a third into the bar. The
-- list starts 20px lower and is as much shorter, so its bottom edge stays put. Once.
local RECIPE_SCAN_LIST_SHIFT = 20
local recipeScanListFitted = false
local function FitRecipeScanList(CraftSim)
    if recipeScanListFitted then return end
    local recipeScan = CraftSim.RECIPE_SCAN
    local tab = recipeScan and recipeScan.frame and recipeScan.frame.content and recipeScan.frame.content.recipeScanTab
    local list = tab and tab.content and tab.content.professionList
    local listFrame = list and list.frame
    if not IsFrame(listFrame) or listFrame:GetNumPoints() ~= 1 then return end
    recipeScanListFitted = true
    local point, relativeTo, relativePoint, x, y = listFrame:GetPoint(1)
    listFrame:ClearAllPoints()
    listFrame:SetPoint(point, relativeTo, relativePoint, x, y - RECIPE_SCAN_LIST_SHIFT)
    listFrame:SetHeight(listFrame:GetHeight() - RECIPE_SCAN_LIST_SHIFT)
end

ns.RegisterAddonSkin("CraftSim", function(S)
    local GGUI = LibStub and LibStub("GGUI-2.1", true)
    if not GGUI then return end

    -- later builds: the widget classes whose frames the classifier knows
    local function HookClass(class, fn)
        if type(class) == "table" and type(class.new) == "function" then ns.SafeHook(class, "new", fn) end
    end
    local function SkinParts(self)
        SkinWidget(S, self.frame)
        SkinWidget(S, self.button)
        SkinWidget(S, self.scrollBar)
    end
    for _, className in ipairs({ "Button", "Checkbox", "TextInput", "Dropdown", "ScrollFrame",
                                 "ScrollingMessageFrame", "CheckboxSelector", "FilterButton", "BlizzardTab" }) do
        HookClass(GGUI[className], SkinParts)
    end
    -- windows run last in their constructor (title, close button and content are made inside it)
    HookClass(GGUI.Frame, function(self)
        SkinWindow(S, self)
        SkinTree(S, self.frame)
        ResweepOnShow(S, self.frame)
    end)
    if GGUI.ToggleButton and type(GGUI.ToggleButton.SetToggle) == "function" then
        ns.SafeHook(GGUI.ToggleButton, "SetToggle", function(self) SyncToggle(self.button) end)
    end
    S.OnLooksChanged(function()
        local r, g, b = S.GetAccentColor()
        for _, wash in pairs(toggleWashes) do wash:SetColorTexture(r, g, b, 0.25) end
    end)

    -- What CraftSim built before login. Its addon table is private; its public API hands it out.
    local api = _G.CraftSimAPI
    local CraftSim = api and type(api.GetCraftSim) == "function" and api:GetCraftSim()
    if type(CraftSim) ~= "table" then return end

    local function IsGGUIFrame(object)
        if type(object) ~= "table" or not object.isGGUI or not IsFrame(object.frame) then return false end
        local class = getmetatable(object)
        while type(class) == "table" do
            if class == GGUI.Frame then return true end
            class = class.super
        end
        return false
    end
    local function SkinExisting(gguiFrame)
        SkinWindow(S, gguiFrame)
        SkinTree(S, gguiFrame.frame)
        ResweepOnShow(S, gguiFrame.frame)
    end
    -- Movable windows register in CraftSim.INIT.FRAMES. Panels docked into Blizzard's profession
    -- frame (e.g. the simulation mode's) don't, but every module keeps its frames on its own table
    -- (CraftSim.SIMULATION_MODE.frame, .frameWO, ...), one level below the addon table.
    for _, gguiFrame in pairs(CraftSim.INIT and CraftSim.INIT.FRAMES or {}) do SkinExisting(gguiFrame) end
    for _, module in pairs(CraftSim) do
        if type(module) == "table" then
            for _, value in pairs(module) do
                if IsGGUIFrame(value) then SkinExisting(value) end
            end
        end
    end
    FitRecipeScanList(CraftSim)
    -- the recipe scan's per-profession results (with the "Sort By" dropdown) are built on demand,
    -- partly with plain CreateFrame, possibly while the window is already open
    local recipeScanUI = CraftSim.RECIPE_SCAN and CraftSim.RECIPE_SCAN.UI
    if recipeScanUI and type(recipeScanUI.CreateProfessionTabContent) == "function" then
        ns.SafeHook(recipeScanUI, "CreateProfessionTabContent", function(_, _, content) SkinTree(S, content) end)
    end
    local craftQueue = CraftSim.CRAFTQ
    if craftQueue then
        for _, key in ipairs({ "queueRecipeButton", "queueRecipeButtonWO" }) do
            local button = craftQueue[key]
            if button then SkinWidget(S, button.frame) end
        end
    end
end)
