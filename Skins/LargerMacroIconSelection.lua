-------------------------------------------------------------------------------
--  LargerMacroIconSelection: the search box it adds to Blizzard's icon pickers
--  (label, matched-link text) and the pickers themselves: panel, name box,
--  okay/cancel buttons, icon type dropdown, texts, grid scroll bar and the
--  grid's slot art.
--
--  LMIS sets each picker up on its first show (macro, equipment set, bank tab,
--  guild bank tab, transmog outfit, and the Bagnon/Baganator bank tabs) and
--  stores the box as popup.SearchBox from LMIS:CreateSearchBox(popup), so the
--  skin runs after that method. Pickers set up before skinning was turned on
--  are listed in LMIS.loadedFrames. The icons themselves keep their stock look.
-------------------------------------------------------------------------------
local _, ns = ...
if not ns.RegisterAddonSkin then return end

-- Regions of a grid button that are the content, not the slot art around it
local function IsSlotArt(button, region)
    if region == button.Icon or region == button.SelectedTexture or region == button.Highlight then return false end
    if button.GetHighlightTexture and region == button:GetHighlightTexture() then return false end
    return region:IsObjectType("Texture")
end

-- The stock slot frame is gold and heavy next to the flat house panel; at half alpha it reads as
-- a subtle well, like EUI's own macro picker. Blizzard doesn't touch these alphas, so per button once.
local dimmedButtons = setmetatable({}, { __mode = "k" })
local function DimSlot(button)
    if dimmedButtons[button] then return end
    dimmedButtons[button] = true
    for _, region in ipairs({ button:GetRegions() }) do
        if IsSlotArt(button, region) then region:SetAlpha(0.5) end
    end
end

-- The grid pools its buttons, and a search can grow the pool, so new buttons are caught after each Update
local hookedGrids = {}
local function DimGrid(scrollBox)
    if not (scrollBox and scrollBox.ForEachFrame) then return end
    if not hookedGrids[scrollBox] then
        hookedGrids[scrollBox] = true
        ns.SafeHook(scrollBox, "Update", function(box) box:ForEachFrame(DimSlot) end)
    end
    scrollBox:ForEachFrame(DimSlot)
end

-- Layout tweaks below shift anchors, so each runs once per frame
local adjusted = setmetatable({}, { __mode = "k" })
local function Once(frame, key)
    local done = adjusted[frame]
    if not done then
        done = {}
        adjusted[frame] = done
    end
    if done[key] then return false end
    done[key] = true
    return true
end

-- The flat box sits on the frame's own rect, which the stock templates keep a few px right of their
-- label with the text flush at the edge (the old art drew the inset). Move the left edge out to the
-- label line and inset the text by the same amount, so the text stays where it was. Our own instead of
-- S.EditBox's padInput: that one is skipped when EUI already skinned the box (its macro picker).
local INPUT_PAD = 6

-- The picker's own code re-sets the name box's text insets after we pad it (the text ended up flush
-- again), so the pad is kept: added on top of whatever inset is set later, and checked on every show
local insetLefts = setmetatable({}, { __mode = "k" })
local settingInsets = false
local function KeepTextInset(editBox)
    if not Once(editBox, "inset") then return end
    local function Apply(box, left, right, top, bottom)
        if settingInsets then return end
        if left == nil then left, right, top, bottom = box:GetTextInsets() end
        local want = (left or 0) + INPUT_PAD
        insetLefts[box] = want
        settingInsets = true
        box:SetTextInsets(want, right or 0, top or 0, bottom or 0)
        settingInsets = false
    end
    local Restore = ns.Safe(function()
        local want = insetLefts[editBox]
        local left, right, top, bottom = editBox:GetTextInsets()
        if want and (left or 0) < want then
            settingInsets = true
            editBox:SetTextInsets(want, right or 0, top or 0, bottom or 0)
            settingInsets = false
        end
    end)
    -- the reset lands later in the same show as our first pass (only the first open lost the pad),
    -- so the check also runs a frame after
    local function RestoreNowAndNextFrame()
        Restore()
        C_Timer.After(0, Restore)
    end
    ns.SafeHook(editBox, "SetTextInsets", Apply)
    editBox:HookScript("OnShow", RestoreNowAndNextFrame)
    Apply(editBox)
    C_Timer.After(0, Restore)
end

local function PadInput(editBox)
    KeepTextInset(editBox)
    if not Once(editBox, "pad") then return end
    local points = {}
    for i = 1, editBox:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = editBox:GetPoint(i)
        if point:find("LEFT") then x = (x or 0) - INPUT_PAD end
        points[i] = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end
    if #points == 0 then return end
    editBox:ClearAllPoints()
    for _, p in ipairs(points) do editBox:SetPoint(unpack(p)) end
end

-- LMIS's box is 15px tall, butts against Okay, and its label sits left of the content column. It is
-- re-anchored on two corners: top and right from Okay (the buttons' height and their gap), bottom and
-- left from the panel, with the left edge pushed right so the "Search:" label starts on the same
-- line as "Choose an Icon:". Measured from the live rects, so it needs a laid-out popup; without one
-- LMIS's own anchors stay.
local FALLBACK_BUTTON_GAP, LABEL_GAP = 4, 8
local function FitSearchBox(searchBox, popup)
    local borderBox = popup.BorderBox
    local okay = borderBox and borderBox.OkayButton
    if not okay then return end
    local popupLeft, popupBottom = popup:GetLeft(), popup:GetBottom()
    local okayBottom = okay:GetBottom()
    local column = borderBox.IconSelectionText or borderBox.EditBoxHeaderText
    local columnLeft = column and column:GetLeft()
    local label = searchBox.searchLabel
    local labelWidth = label and label:GetStringWidth()
    if not (popupLeft and popupBottom and okayBottom and columnLeft and labelWidth) then return end
    if not Once(searchBox, "fit") then return end

    local gap = FALLBACK_BUTTON_GAP
    local cancel = borderBox.CancelButton
    local okayRight, cancelLeft = okay:GetRight(), cancel and cancel:GetLeft()
    if okayRight and cancelLeft and cancelLeft > okayRight then gap = cancelLeft - okayRight end

    -- LMIS hangs the label off the box's left edge with this gap
    local x = columnLeft - popupLeft + labelWidth + LABEL_GAP
    searchBox:ClearAllPoints()
    searchBox:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", x, okayBottom - popupBottom)
    searchBox:SetPoint("TOPRIGHT", okay, "TOPLEFT", -gap, 0)
end

-- The stock grid ends just above the buttons, where the old border art kept them apart; on the flat
-- panel the footer row needs room of its own, so the grid's bottom edge moves up
local FOOTER_GAP = 8
local function LiftGridBottom(grid)
    if not Once(grid, "lift") then return end
    local points, hasBottom = {}, false
    for i = 1, grid:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = grid:GetPoint(i)
        if point:find("BOTTOM") then
            y = (y or 0) + FOOTER_GAP
            hasBottom = true
        end
        points[i] = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end
    if hasBottom then
        grid:ClearAllPoints()
        for _, p in ipairs(points) do grid:SetPoint(unpack(p)) end
    elseif #points > 0 then
        -- anchored at the top with a fixed size
        local height = grid:GetHeight()
        if height and height > FOOTER_GAP then grid:SetHeight(height - FOOTER_GAP) end
    end
end

local function SkinFontStrings(S, frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("FontString") then S.Font(region) end
    end
end

-- "Choose an Icon:" heads the whole grid but is set as small as the field labels; a bit larger it
-- reads as the section heading. The stock size is taken once, so re-runs don't keep growing it.
local HEADING_GROWTH = 2
local headingSizes = setmetatable({}, { __mode = "k" })
local function EnlargeHeading(S, fontString)
    if not fontString then return end
    local _, size = fontString:GetFont()
    if not headingSizes[fontString] then
        if not size then return end
        headingSizes[fontString] = size + HEADING_GROWTH
    end
    local path, outline = S.GetFont()
    if path then fontString:SetFont(path, headingSizes[fontString], outline or "") end
end

local function SkinSearchBox(S, searchBox, popup)
    if not searchBox then return end
    -- InputBoxTemplate's caps are the box's own regions, so S.EditBox fades them
    S.EditBox(searchBox)
    -- the label is measured for the layout, so it gets the house font first
    if searchBox.searchLabel then
        S.Font(searchBox.searchLabel)
        S.White(searchBox.searchLabel)
    end
    -- the box is re-anchored outright, so it only needs the text inset of PadInput
    KeepTextInset(searchBox)
    FitSearchBox(searchBox, popup)
    -- the gray matched-link text keeps its color: it is a hint, not a label
    if searchBox.linkLabel then S.Font(searchBox.linkLabel) end
end

local function SkinBorderBox(S, borderBox)
    if not borderBox then return end
    S.FadeRegions(borderBox)
    if borderBox.NineSlice then S.FadeNineSlice(borderBox.NineSlice) end

    local nameBox = borderBox.IconSelectorEditBox
    if nameBox then
        S.EditBox(nameBox)
        PadInput(nameBox)
        -- the instructions template names its caps globally, outside the box's own region list
        local name = nameBox:GetName()
        if name then
            for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
                local cap = _G[name .. suffix]
                if cap and cap.SetAlpha then cap:SetAlpha(0) end
            end
        end
    end

    for _, key in ipairs({ "OkayButton", "CancelButton" }) do
        local button = borderBox[key]
        if button then
            S.Button(button)
            S.WhiteButtonLabel(button)
        end
    end

    -- retail's menu dropdown, and the classic UIDropDownMenu spelled with a capital D
    for _, key in ipairs({ "IconTypeDropdown", "IconTypeDropDown" }) do
        if borderBox[key] then S.Dropdown(borderBox[key]) end
    end

    SkinFontStrings(S, borderBox)
    for _, key in ipairs({ "EditBoxHeaderText", "IconSelectionText" }) do
        if borderBox[key] then S.White(borderBox[key]) end
    end
    EnlargeHeading(S, borderBox.IconSelectionText)
    -- "Currently Selected" keeps its gold: it is what tells the header from the hint below it
    local selectedArea = borderBox.SelectedIconArea
    if selectedArea then SkinFontStrings(S, selectedArea.SelectedIconText) end
end

local function SkinPopup(S, popup)
    if not popup or popup:IsForbidden() then return end
    S.Panel(popup)
    if popup.NineSlice then S.FadeNineSlice(popup.NineSlice) end
    SkinBorderBox(S, popup.BorderBox)

    local grid = popup.IconSelector
    if grid then
        S.FadeRegions(grid)
        ns.SkinScrollBar(S, grid.ScrollBar)
        DimGrid(grid.ScrollBox)
        LiftGridBottom(grid)
    end

    SkinSearchBox(S, popup.SearchBox, popup)

    -- again on every show: retries the layout should the first pass have run before the popup had
    -- rects, and catches anything the picker rebuilt; primitives and layout are guarded
    if Once(popup, "show") then
        popup:HookScript("OnShow", ns.Safe(function(self) SkinPopup(S, self) end))
    end
end

ns.RegisterAddonSkin("LargerMacroIconSelection", function(S)
    local LMIS = _G.LargerMacroIconSelection
    if not LMIS then return end

    if type(LMIS.CreateSearchBox) == "function" then
        ns.SafeHook(LMIS, "CreateSearchBox", function(_, popup) SkinPopup(S, popup) end)
    end
    -- pickers LMIS already set up this session (skinning turned on live)
    if type(LMIS.loadedFrames) == "table" then
        for popup in pairs(LMIS.loadedFrames) do
            if type(popup) == "table" and popup.SearchBox then SkinPopup(S, popup) end
        end
    end
end)
