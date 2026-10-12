# EllesmereUI AddonSkins

Skins other addons to match the EllesmereUI look.

EllesmereUI has a public skinning API that addon authors can call to get their frames painted in the
user's EllesmereUI theme. Not every author wants that integration inside their own addon. This addon
does the job from the outside: it is the glue between EllesmereUI and those addons, so the addons
themselves stay untouched.

When EllesmereUI and a supported addon are both loaded, that addon's frames get skinned. They follow
your EllesmereUI theme, accent color and font, including live changes.

## Supported addons

These addons will be skinned:

- Auctionator
- BugSack
- CraftSim
- LargerMacroIconSelection
- RareScanner (Partial skin: only the popup that appears when it finds a rare, treasure or event. The 3D model, loot bar and arrows keep their look)
- Talent Loadout Manager
- Talent Tree Tweaks

You can toggle each addon via **EllesmereUI Options → Blizz UI Enhanced → Blizzard Window Skins → Third-Party Addons**

From there you can switch off all third-party skins with the master toggle, or individual addons.
Turning a skin on applies right away. Turning one off needs a `/reload`.

### Possible future addons

Not skinned yet, but candidates for upcoming skins:

- Mythic Dungeon Tools (MDT)
- Northern Sky Raid Tools (NSRT)
- Simulationcraft (SimCraft)

### Addons supported by other skinning addons

These addons are not supported by **EllesmereUI AddonSkins** because other authors have already created a skinning addon:

- [BetterBags](https://www.curseforge.com/wow/addons/betterbags-ellesmereui-theme)
- [PremadeGroupsFilter](https://www.curseforge.com/wow/addons/premade-groups-filter-ellesmereui)
- [Pretty Reps](https://www.curseforge.com/wow/addons/pretty-reps-eui-skin)
- [Rematch](https://www.curseforge.com/wow/addons/rematch-ellesmereui-skin)

## Requirements

- **EllesmereUI** with its *Blizz UI Enhanced* module enabled. That module provides the skinning API.
- One or more of the supported addons. Skins for addons you don't have installed simply never run.

## Installation

Install it like any other addon, into `World of Warcraft\_retail_\Interface\AddOns\EllesmereUI_AddonSkins\`,
and restart the game client. Or use your preferred WoW addon client.

## Good to know

- If a supported addon ever ships its own EllesmereUI skin, that skin wins and the one here is
  ignored, so you never get both.
- A broken skin can never break the skinned addon: errors in a skin are caught and reported.

## Contributing

Want to add a skin for another addon? See [CONTRIBUTING.md](CONTRIBUTING.md).

## Big Thanks

- **Ellesmere**, for EllesmereUI and for its skinning API. Without that API this addon couldn't exist,
  because every skin here is built on it.
- **Numy**, author of Talent Tree Tweaks and Talent Loadout Manager, for two great addons that
  make talents much nicer to work with.
- **plusmouse** and **Borjamacare**, authors of Auctionator, for the addon and for supporting the idea
  of skinning it through a separate addon.
- **Funkeh**, author of BugSack, for the addon every UI tinkerer keeps open while things break.
- **maqjav** and **Maciza-Tyrande**, authors of RareScanner, for never letting a rare slip by unnoticed.
- **genju**, author of CraftSim, for turning profession math into something you can actually plan with.
- **Xinhuan** and **Ketho**, authors of LargerMacroIconSelection, for making the right icon a quick search away.

All skinned addons belong to their respective authors. This addon only styles them from the outside
and is not affiliated with them. Please report problems with a skin here, not to the authors of the
skinned addons.
