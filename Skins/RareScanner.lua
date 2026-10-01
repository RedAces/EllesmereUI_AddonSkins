-------------------------------------------------------------------------------
--  RareScanner: only the "found something" popup (RARESCANNER_BUTTON), the
--  clickable bar that appears when a rare, treasure or event shows up.
--
--  The popup is built once while RareScanner loads, so it exists when the
--  skin runs. It is a secure action button (clicking it targets the find),
--  so the skin stays purely visual: art faded, own regions added, never its
--  size, position, attributes or scripts. The 3D model above it, the loot
--  bar below, the navigation arrows and the filter (stop/go) icon buttons
--  keep RareScanner's look.
-------------------------------------------------------------------------------
local _, ns = ...
if not ns.RegisterAddonSkin then return end

local POPUP_NAME = "RARESCANNER_BUTTON"

ns.RegisterAddonSkin("RareScanner", function(S)
    local popup = _G[POPUP_NAME]
    if not popup then return end

    -- The parchment (normal texture), the title ribbon and the tooltip-style backdrop edge are all
    -- regions of the button, so S.Button takes them along and lays down the flat house block with
    -- its border and hover wash. RareScanner's own hover recolors the backdrop edge, which stays
    -- faded; the wash takes over that cue.
    S.Button(popup)
    if popup.CloseButton then S.CloseButton(popup.CloseButton) end

    -- the name and the "click to target" line, in the user's UI font
    if popup.Title then S.Font(popup.Title) end
    if popup.Description_text then S.Font(popup.Description_text) end
end)
