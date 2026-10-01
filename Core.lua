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
