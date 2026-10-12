-------------------------------------------------------------------------------
--  TalentLoadoutManager: the loadout sidebar next to the talent frame (and
--  next to TalentTreeViewer's), its toggle button and its import dialog.
--
--  TLM builds sidebar + import dialog once per sidebar module, in SetupHook,
--  when the talent UI loads, and then fires its SideBarLoaded event. Sidebars
--  set up earlier are listed in TalentLoadoutManager.sideBars.
-------------------------------------------------------------------------------
local _, ns = ...
if not ns.RegisterAddonSkin then return end

local ADDON = "TalentLoadoutManager"

--- Runs fn(module) for every sidebar module that is already set up, and for each one set up later.
local function ForEachSideBar(fn)
    local TLM = _G.TalentLoadoutManager
    local event = type(TLM) == "table" and TLM.Event and TLM.Event.SideBarLoaded
    if not (event and TLM.RegisterCallback and type(TLM.sideBars) == "table") then return end
    local safeFn = ns.Safe(fn)
    for _, module in pairs(TLM.sideBars) do
        if module.SideBar then safeFn(module) end
    end
    -- the registry keys callbacks by owner, so every caller needs its own owner table
    TLM:RegisterCallback(event, function(_, _, module)
        if type(module) == "table" then safeFn(module) end
    end, {})
end

-- References on the talents tab mark sidebar and toggle button as addon-owned, so EllesmereUI's
-- Blizzard talent-frame skin, which sweeps that frame, leaves them alone instead of flattening the
-- toggle button's arrow texture. That is EUI's own window skin, independent of the third-party skin
-- toggle, so this runs whenever TLM is loaded, and in the same call as TLM creating the frames:
-- EUI sweeps the talent frame at the same ADDON_LOADED.
local function MarkAddonOwned(module)
    local sideBar = module.SideBar
    if not sideBar then return end
    local talentsTab = sideBar:GetParent()
    if not talentsTab then return end
    talentsTab.TalentLoadoutManager_SideBar = sideBar
    talentsTab.TalentLoadoutManager_ToggleSideBarButton = sideBar.ToggleSideBarButton
end

if C_AddOns.IsAddOnLoaded(ADDON) then
    ForEachSideBar(MarkAddonOwned)
end

local function SkinButton(S, button)
    if not button then return end
    S.Button(button)
    S.StateButtonLabel(button)
end

local function SkinSideBar(S, sideBar)
    -- SaveButton is disabled when there is nothing to save
    for _, button in ipairs({ sideBar.CreateButton, sideBar.ImportButton, sideBar.SaveButton, sideBar.ConfigButton }) do
        SkinButton(S, button)
    end
    -- the toggle's arrow is its Normal/HighlightTexture, which S.Button would fade unless kept by key
    local toggleButton = sideBar.ToggleSideBarButton
    if toggleButton then
        toggleButton.Arrow = toggleButton:GetNormalTexture()
        toggleButton.ArrowHighlight = toggleButton:GetHighlightTexture()
        S.Button(toggleButton, { "Arrow", "ArrowHighlight" })
    end
end

-- moves only the points of region that are anchored to anchor
local function ShiftPointsFrom(region, anchor, dx, dy)
    local points, moved = {}, false
    for i = 1, region:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
        if relativeTo == anchor then
            moved = true
            x, y = x + dx, y + dy
        end
        points[i] = { point, relativeTo, relativePoint, x, y }
    end
    if not moved then return end
    region:ClearAllPoints()
    for _, p in ipairs(points) do region:SetPoint(unpack(p)) end
end

local function SkinImportDialog(S, dialog)
    S.Shell(dialog)
    if dialog.Border then dialog.Border:SetAlpha(0) end
    local title = dialog.Title or (dialog.TitleContainer and dialog.TitleContainer.TitleText) or dialog.TitleText
    if title then
        S.Font(title)
        S.White(title)
        -- seat the title on the shell's 25px top bar
        title:ClearAllPoints()
        title:SetPoint("CENTER", dialog, "TOP", 0, -11.5)
    end
    -- AcceptButton is disabled until a string and name are entered
    SkinButton(S, dialog.AcceptButton)
    SkinButton(S, dialog.CancelButton)
    if dialog.ImportControl and dialog.ImportControl.InputContainer then
        S.Panel(dialog.ImportControl.InputContainer)
    end
    -- AutoApplyCheckbox only exists when the module implements auto apply
    for _, key in ipairs({ "AutoApplyCheckbox", "ImportIntoCurrentLoadoutCheckbox" }) do
        local checkbox = dialog[key]
        if checkbox then
            S.Checkbox(checkbox)
            -- EUI's box fills the whole button, which TLM seats right below the name input; the
            -- second checkbox hangs off the first, so only the one anchored to the input moves
            if dialog.NameControl then ShiftPointsFrom(checkbox, dialog.NameControl, 0, -6) end
            local label = checkbox.text
            if label then
                S.White(label)
                -- the template seats the label flush against the button
                ShiftPointsFrom(label, checkbox, 6, 0)
            end
        end
    end

    -- name input: 15px lower and 20px shorter, to clear the shell's top bar spacing
    local editBox = dialog.NameControl and dialog.NameControl.EditBox
    if not editBox then return end
    S.EditBox(editBox)
    local points, hasBottom = {}, false
    for i = 1, editBox:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = editBox:GetPoint(i)
        if point:find("BOTTOM") then
            hasBottom = true
            points[i] = { point, relativeTo, relativePoint, x, y + 5 }
        else
            points[i] = { point, relativeTo, relativePoint, x, y - 15 }
        end
    end
    editBox:ClearAllPoints()
    for _, p in ipairs(points) do editBox:SetPoint(unpack(p)) end
    local height = editBox:GetHeight()
    if not hasBottom and height > 20 then editBox:SetHeight(height - 20) end
end

-- the layout tweaks above are not idempotent, so every module is skinned exactly once
local skinned = {}

ns.RegisterAddonSkin(ADDON, function(S)
    ForEachSideBar(function(module)
        if skinned[module] or not (module.SideBar and module.importDialog) then return end
        skinned[module] = true
        SkinSideBar(S, module.SideBar)
        SkinImportDialog(S, module.importDialog)
    end)
end)
