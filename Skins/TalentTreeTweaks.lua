-------------------------------------------------------------------------------
--  TalentTreeTweaks: the buttons it adds to the talent frame and the
--  "Import into current loadout" checkbox + button in the import dialog.
--
--  TTT creates these lazily, from each module's SetupHook once
--  Blizzard_PlayerSpells loads (and again after a module is re-enabled), so
--  we skin whatever already exists and post-hook SetupHook for the rest.
--  The primitives are idempotent, re-skinning on every SetupHook is free.
-------------------------------------------------------------------------------
local _, ns = ...
if not ns.RegisterAddonSkin then return end

local function SkinButton(S, button)
    if not button then return end
    S.Button(button)
    S.StateButtonLabel(button)
end

-- ExportInspectedBuild: "Post in Chat" (+ "Export" on Forever) at the bottom of the talent frame
local function SkinExportButtons(S, module)
    SkinButton(S, module.linkButton)
    SkinButton(S, module.exportButton)
end

local checkboxAdjusted = false
-- ImportIntoCurrentLoadout: checkbox + accept button in the import dialog, "Import" button on Forever
local function SkinImport(S, module)
    SkinButton(S, module.acceptButton)
    local talentsTab = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    SkinButton(S, talentsTab and talentsTab.TalentTreeTweaks_ImportButton)

    local checkbox = module.checkbox
    if not checkbox then return end
    S.Checkbox(checkbox)
    if checkbox.text then S.White(checkbox.text) end
    if checkboxAdjusted then return end
    checkboxAdjusted = true

    -- the skinned box has no transparent padding like the stock art, so the label needs its own gap
    if checkbox.text then
        checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 6, 1)
        checkbox:SetHitRectInsets(-10, -checkbox.text:GetStringWidth() - 6, -5, 0)
    end
    -- the skinned checkbox fills its whole 24px and runs into the buttons below it, so lift the name
    -- control (and the checkbox anchored to it) into the spare room below the import text box
    local nameControl = checkbox:GetParent() and checkbox:GetParent().NameControl
    if not nameControl then return end
    local points = {}
    for i = 1, nameControl:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = nameControl:GetPoint(i)
        points[i] = { point, relativeTo, relativePoint, x, y + 18 }
    end
    nameControl:ClearAllPoints()
    for _, p in ipairs(points) do nameControl:SetPoint(unpack(p)) end
end

ns.RegisterAddonSkin("TalentTreeTweaks", function(S)
    ns.OnAceModuleMethod("TalentTreeTweaks", "ExportInspectedBuild", "SetupHook", function(module)
        SkinExportButtons(S, module)
    end)
    ns.OnAceModuleMethod("TalentTreeTweaks", "ImportIntoCurrentLoadout", "SetupHook", function(module)
        SkinImport(S, module)
    end)
end)
