-------------------------------------------------------------------------------
--  EllesmereUI_AddonSkins: glue between EllesmereUI's skinning API
--  (SKINNING_API.md in EllesmereUI) and addons that don't ship their own
--  EllesmereUI integration.
--
--  Each file in Skins\ calls ns.RegisterAddonSkin("<AddonFolderName>", fn).
--  Once that addon is loaded, fn is handed to EllesmereUI.RegisterSkin under
--  the addon's own name, so it shows up (and can be toggled) by that name in
--  EllesmereUI's Third-Party Addons options. EllesmereUI keeps the first
--  registration per name: should the addon ever register a skin itself, its
--  own one wins and ours is ignored.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

if not (EllesmereUI and EllesmereUI.RegisterSkin) then return end

-- addon folder name -> skin callback, until that addon is loaded
local pendingSkins = {}

--- Registers the EllesmereUI skin for another addon; it runs only if that addon gets loaded
--- @param addonName string the addon's folder name
--- @param apply fun(S: table) the skin callback, see EllesmereUI.RegisterSkin
function ns.RegisterAddonSkin(addonName, apply)
    pendingSkins[addonName] = apply
end

local function TryRegister(addonName)
    local apply = pendingSkins[addonName]
    if not apply or not C_AddOns.IsAddOnLoaded(addonName) then return end
    pendingSkins[addonName] = nil
    EllesmereUI.RegisterSkin(addonName, apply)
end

--- Wraps fn so an error in it is only reported, never raised into the caller (the hooked addon)
--- @param fn function
--- @return function
function ns.Safe(fn)
    return function(...)
        xpcall(fn, geterrorhandler(), ...)
    end
end

--- hooksecurefunc whose hook can never break the hooked addon: errors are only reported
--- @param tbl table
--- @param method string
--- @param hook function
function ns.SafeHook(tbl, method, hook)
    hooksecurefunc(tbl, method, ns.Safe(hook))
end

-------------------------------------------------------------------------------
--  Shared skin helpers, for widgets the API's primitives don't fully cover
-------------------------------------------------------------------------------
local function FadeTree(S, frame, keep)
    if keep[frame] then return end
    S.FadeRegions(frame)
    for _, child in ipairs({ frame:GetChildren() }) do FadeTree(S, child, keep) end
end

--- S.ScrollBar, plus the art it misses: WowTrimScrollBar's trough and stepper caps sit on child
--- frames (S.ScrollBar handles MinimalScrollBar's flat layout), so the whole tree is faded after it.
--- The thumb is kept: it carries the house thumb strip S.ScrollBar paints.
--- @param S table the skinning API
--- @param scrollBar Frame?
function ns.SkinScrollBar(S, scrollBar)
    if not scrollBar then return end
    S.ScrollBar(scrollBar)
    local keep = {}
    local thumb = (scrollBar.Track and scrollBar.Track.Thumb) or (scrollBar.GetThumb and scrollBar:GetThumb())
    if thumb then keep[thumb] = true end
    FadeTree(S, scrollBar, keep)
end

--- One physical pixel in the region's own coordinate space, the seam EUI puts between flat tabs
--- @param region Region
--- @return number
function ns.OnePixel(region)
    local _, height = GetPhysicalScreenSize()
    local scale = region:GetEffectiveScale()
    if not height or height <= 0 or not scale or scale < 0.1 or scale > 10 then return 1 end
    return 768 / height / scale
end

-- tabs already laid out; the height trim must not repeat
local laidOutTabs = {}

--- Lays a skinned (S.Tab) tab out like EUI's own tab rows: 2px shorter, once, and chained to the
--- previous tab's right edge with a 1px seam. Without `previous` the tab keeps its own seat.
--- @param tab Button
--- @param previous Region?
function ns.LayoutTab(tab, previous)
    if laidOutTabs[tab] then return end
    laidOutTabs[tab] = true
    local height = tab:GetHeight()
    if height and height > 2 then tab:SetHeight(height - 2) end
    if previous then
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", previous, "RIGHT", ns.OnePixel(tab), 0)
    end
end

-- tabs already hooked by ns.WidenTab
local widenedTabs = {}

local function FitTab(tab, padding)
    local widest = 0
    for _, region in ipairs({ tab:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local width = region.GetUnboundedStringWidth and region:GetUnboundedStringWidth() or region:GetStringWidth()
            if width and width > widest then widest = width end
        end
    end
    if widest > 0 and tab:GetWidth() < widest + 2 * padding then tab:SetWidth(widest + 2 * padding) end
end

--- Gives a skinned (S.Tab) tab room for its label. Blizzard's tab templates size a tab to its own
--- label, capped, often from their OnShow, and the house label (EUI's font) is wider than Blizzard's,
--- so the text ends up cramped. The tab is widened to its widest label (measured unbounded, since the
--- template truncates its own) plus padding on each side, now and after every OnShow. Never narrows.
--- @param tab Button
--- @param padding number? per side, default 16
function ns.WidenTab(tab, padding)
    padding = padding or 16
    if not widenedTabs[tab] then
        widenedTabs[tab] = true
        tab:HookScript("OnShow", ns.Safe(function(self) FitTab(self, padding) end))
    end
    FitTab(tab, padding)
end

--- Skins a left-to-right row of tabs with S.Tab and lays it out via ns.LayoutTab
--- @param S table the skinning API
--- @param tabs Button[]
function ns.SkinTabRow(S, tabs)
    local previous
    for _, tab in ipairs(tabs) do
        S.Tab(tab)
        ns.LayoutTab(tab, previous)
        previous = tab
    end
end

--- Runs fn(module) on an AceAddon module now, and again after every call of module[method].
--- Meant for addons that build their frames lazily: fn sees whatever exists so far, the hook
--- catches the rest. Does nothing if the addon is not an AceAddon or lacks the module/method.
--- @param addonName string the AceAddon name (usually the folder name)
--- @param moduleName string
--- @param method string e.g. "SetupHook"
--- @param fn fun(module: table)
function ns.OnAceModuleMethod(addonName, moduleName, method, fn)
    local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
    local addon = AceAddon and AceAddon:GetAddon(addonName, true)
    local module = addon and addon:GetModule(moduleName, true)
    if not (module and type(module[method]) == "function") then return end
    xpcall(fn, geterrorhandler(), module)
    ns.SafeHook(module, method, fn)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedName)
    if loadedName == ADDON_NAME then
        -- the skin files are in by now; OptionalDeps loaded before us
        for addonName in pairs(pendingSkins) do TryRegister(addonName) end
    else
        -- load-on-demand addons, or ones loading after us
        TryRegister(loadedName)
    end
end)
