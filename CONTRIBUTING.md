# Contributing to EllesmereUI AddonSkins

Notes for anyone who wants to add or change a skin. For what the addon does and how to use it, see
[README.md](README.md).

## How it works

- Each skin is registered with `EllesmereUI.RegisterSkin` under the **skinned addon's own name**,
  not under this addon's name, so the EllesmereUI options list and toggle it by that name.
- A skin is only registered once its addon is loaded. That includes load-on-demand addons and addons
  that load after this one.
- EllesmereUI keeps the **first** registration per name. If a supported addon ever ships its own
  EllesmereUI skin, that skin wins and the one here is ignored, so you never get both.
- Most of these addons build their frames lazily, for example once the talent UI loads. The skins
  hook the method that creates those frames, or listen to the addon's own event for it where it offers
  one (Talent Loadout Manager does), so frames made at any point in the session get skinned too.
- All hooks are post-hooks (`hooksecurefunc`) with their errors caught and reported. A broken skin can
  never break the skinned addon. EllesmereUI isolates every skin callback the same way.
- Talent Loadout Manager: EllesmereUI's own skin for Blizzard's talent window would otherwise mistake
  the sidebar for part of that window and flatten its toggle arrow. This addon marks the sidebar as
  addon-owned so EllesmereUI leaves it alone. That runs whenever Talent Loadout Manager is loaded,
  even with its skin switched off, because it concerns EllesmereUI's Blizzard window skin.

## Adding a skin for another addon

1. Create `Skins\<AddonFolderName>.lua`:

   ```lua
   local _, ns = ...
   if not ns.RegisterAddonSkin then return end -- EllesmereUI or its skinning API is missing

   ns.RegisterAddonSkin("SomeAddon", function(S)
       -- frames that already exist at login
       S.Shell(SomeAddonMainFrame)
       S.Button(SomeAddonMainFrame.OkayButton)

       -- frames an AceAddon module creates later: runs now and after every SetupHook call
       ns.OnAceModuleMethod("SomeAddon", "SomeModule", "SetupHook", function(module)
           if module.button then S.Button(module.button) end
       end)
   end)
   ```

2. Add the file to the skin list in `EllesmereUI_AddonSkins.toc`, below `Core.lua`.
3. Add the addon to `## OptionalDeps` in the TOC, so it loads before this addon.
   Keep both TOC lists sorted alphabetically by addon folder name.
4. Add the addon to the **Supported addons** table in [README.md](README.md) and its author(s) to
   **Big Thanks** there.

The available primitives (`S.Shell`, `S.Button`, `S.EditBox`, `S.Checkbox`, `S.ScrollBar`, `S.Tab`, ...)
are documented in `SKINNING_API.md` in the EllesmereUI repository. They are idempotent, so calling them
again on an already skinned frame is safe. Your own layout tweaks (moving anchors, resizing) usually
are not, so guard them so they run only once per frame.

A new skin file changes the TOC, so the game client needs a restart to pick it up. Changes to existing
Lua files only need a `/reload`.

## Helpers in `Core.lua`

| Function | Purpose |
|---|---|
| `ns.RegisterAddonSkin(addonName, fn)` | Registers `fn(S)` as the EllesmereUI skin for `addonName`, once that addon is loaded |
| `ns.OnAceModuleMethod(addonName, moduleName, method, fn)` | Runs `fn(module)` on an AceAddon module now and after every call of `module[method]`. Does nothing if the addon, module or method doesn't exist |
| `ns.Safe(fn)` | Wraps `fn` so that an error in it is reported instead of being passed on to the caller |
| `ns.SafeHook(tbl, method, fn)` | `hooksecurefunc` that reports errors in `fn` instead of passing them on to the hooked code |
| `ns.SkinScrollBar(S, scrollBar)` | `S.ScrollBar` plus the art it misses on `WowTrimScrollBar` (trough and stepper caps on child frames). The thumb is kept |
| `ns.SkinTabRow(S, tabs)` | Skins a left-to-right row of tabs with `S.Tab` and lays it out like EllesmereUI's own tab rows (see `ns.LayoutTab`) |
| `ns.LayoutTab(tab, previous)` | Makes a tab 2px shorter and chains it to `previous` with a 1px seam, once per tab. Without `previous` the tab keeps its position |
| `ns.WidenTab(tab, padding)` | Widens a skinned tab to fit its label plus `padding` (default 16) per side, now and after every `OnShow`, since Blizzard's tab templates cap the width and EllesmereUI's label font is wider |
| `ns.OnePixel(region)` | One physical pixel in the region's own coordinate space |

## Guidelines

- Only touch the skinned addon from the outside: hooks, public frames, AceAddon modules. Never change
  its files.
- Use EllesmereUI's primitives rather than custom textures or colors, so the skin keeps up with theme changes.
- Code defensively. Other addons change between versions, so check that a frame or field exists
  before skinning it.
