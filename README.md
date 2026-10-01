# EllesmereUI AddonSkins

Skins other addons to match the EllesmereUI look.

EllesmereUI has a public skinning API that addon authors can call to get their frames painted in the
user's EllesmereUI theme. Not every author wants that integration inside their own addon. This addon
does the job from the outside: it is the glue between EllesmereUI and those addons, so the addons
themselves stay untouched.

When EllesmereUI and a supported addon are both loaded, that addon's frames get skinned. They follow
your EllesmereUI theme, accent color and font, including live changes.

## Supported addons

| Addon | What gets skinned |
|---|---|
| Auctionator | Its four tabs on the auction house (Shopping, Selling, Cancelling, Auctionator) and their content: buttons, search and price inputs, checkboxes, radio buttons, dropdowns, scroll bars, insets, result lists with their column headers, and the small tabs inside each tab. Also the buy item and buy commodity views, the add/edit item dialog, the list import/export and price history windows, and Auctionator's own confirmation popups. Item rows and icons keep their stock look |
| BugSack | The sack window: its frame (without the portrait), close button, the filter box on the title bar, the "< Previous", "Send bugs" and "Next >" buttons, the scroll bar, and the three session tabs ("All bugs", "Current session", "Previous session"). The title texts move to the window edge now that the portrait is gone, and the tabs get room for their labels. The error text itself keeps BugSack's look |
| Talent Loadout Manager | The loadout sidebar next to the talent frame (and next to Talent Tree Viewer's), its buttons and collapse toggle, and its import dialog |
| Talent Tree Tweaks | The buttons it adds to the talent frame ("Post in Chat", plus "Export" and "Import" on Forever), and the "Import into current loadout" checkbox and accept button in the talent import dialog |

More addons will follow.

## Requirements

- **EllesmereUI** with its *Blizz UI Enhanced* module enabled. That module provides the skinning API.
- One or more of the supported addons. Skins for addons you don't have installed simply never run.

## Installation

Install it like any other addon, into `World of Warcraft\_retail_\Interface\AddOns\EllesmereUI_AddonSkins\`,
and restart the game client.

## Turning skins on and off

Every skinned addon shows up under its own name in EllesmereUI's options:

**Blizz UI Enhanced → Blizzard Window Skins → Third-Party Addons**

From there you can switch off all third-party skins with the master toggle, or individual addons.
Turning a skin on applies right away. Turning one off needs a `/reload`.

## How it works

- Each skin is registered with `EllesmereUI.RegisterSkin` under the **skinned addon's own name**,
  not under this addon's name, so the EllesmereUI options list and toggle it by that name.
- A skin is only registered once its addon is loaded. That includes load-on-demand addons and addons
  that load after this one.
- EllesmereUI keeps the **first** registration per name. If a supported addon ever ships its own
  EllesmereUI skin, that skin wins and the one here is ignored, so you never get both.
- Most of these addons build their frames lazily, for example once the talent UI loads. The skins
  hook the method that creates those frames, so frames made at any point in the session get skinned too.
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

2. Add the file to `EllesmereUI_AddonSkins.toc`, below the existing skins.
3. Add the addon to `## OptionalDeps` in the TOC, so it loads before this addon.

The available primitives (`S.Shell`, `S.Button`, `S.EditBox`, `S.Checkbox`, `S.ScrollBar`, `S.Tab`, ...)
are documented in `SKINNING_API.md` in the EllesmereUI repository. They are idempotent, so calling them
again on an already skinned frame is safe. Your own layout tweaks (moving anchors, resizing) usually
are not, so guard them so they run only once per frame.

### Helpers in `Core.lua`

| Function | Purpose |
|---|---|
| `ns.RegisterAddonSkin(addonName, fn)` | Registers `fn(S)` as the EllesmereUI skin for `addonName`, once that addon is loaded |
| `ns.OnAceModuleMethod(addonName, moduleName, method, fn)` | Runs `fn(module)` on an AceAddon module now and after every call of `module[method]`. Does nothing if the addon, module or method doesn't exist |
| `ns.Safe(fn)` | Wraps `fn` so that an error in it is reported instead of being passed on to the caller |
| `ns.SafeHook(tbl, method, fn)` | `hooksecurefunc` that reports errors in `fn` instead of passing them on to the hooked code |
| `ns.SkinScrollBar(S, scrollBar)` | `S.ScrollBar` plus the art it misses on `WowTrimScrollBar` (trough and stepper caps on child frames). The thumb is kept |
| `ns.SkinTabRow(S, tabs)` | Skins a left-to-right row of tabs with `S.Tab` and lays it out like EllesmereUI's own tab rows (see `ns.LayoutTab`) |
| `ns.LayoutTab(tab, previous)` | Makes a tab 2px shorter and chains it to `previous` with a 1px seam, once per tab. Without `previous` the tab keeps its position |
| `ns.OnePixel(region)` | One physical pixel in the region's own coordinate space |

### Guidelines

- Only touch the skinned addon from the outside: hooks, public frames, AceAddon modules. Never change
  its files.
- Use EllesmereUI's primitives rather than custom textures or colors, so the skin keeps up with theme changes.
- Code defensively. Other addons change between versions, so check that a frame or field exists
  before skinning it.

## Big Thanks

- **Ellesmere**, for EllesmereUI and for its skinning API. Without that API this addon couldn't exist,
  because every skin here is built on it.
- **Numy**, author of Talent Tree Tweaks and Talent Loadout Manager, for two great addons that
  make talents much nicer to work with.
- **plusmouse** and **Borjamacare**, authors of Auctionator, for the addon and for supporting the idea
  of skinning it through a separate addon.
- **Funkeh**, author of BugSack, for the addon every UI tinkerer keeps open while things break.

All skinned addons belong to their respective authors. This addon only styles them from the outside
and is not affiliated with them. Please report problems with a skin here, not to the authors of the
skinned addons.
