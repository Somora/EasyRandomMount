# EasyRandomMount

EasyRandomMount is a World of Warcraft addon that gives you one smart random mount keybind.

It can prefer flying mounts, use water mounts underwater, trigger falling rescue spells/items, respect Blizzard Mount Journal favorites, and exclude mounts you never want through a blacklist.

## Features

- Random mount keybind with automatic dismount.
- Extra keybinds for repair mounts and auction house mounts.
- Secure combat fallback for class movement/falling tools where Blizzard allows them.
- Flying, water, skyriding, and water-surface mount preferences.
- Falling rescue list for spells and items such as Slow Fall, Levitate, Glide, gliders, and kites.
- Blizzard favorite support: use all mounts, prefer favorites, or only favorites.
- Mount blacklist with options UI, slash commands, and Mount Journal right-click support.
- Scrollable blacklist for larger mount collections.
- Optional debug commands for support/testing.

## Setup

1. Put the `EasyRandomMount` folder in your WoW addons directory.
2. Enable `EasyRandomMount` in the addon list.
3. Bind it under `Key Bindings > AddOns > EasyRandomMount`.
4. Use `/erm options` to configure it.

## Options

The settings are split into three pages:

- `EasyRandomMount`: general mount behavior.
- `EasyRandomMount > Falling`: falling rescue spell/item priority.
- `EasyRandomMount > Blacklist`: mounts that should never be randomly selected.

## Slash Commands

- `/erm` uses the random mount keybind behavior.
- `/erm repair` summons a repair mount.
- `/erm ah` summons an auction house mount.
- `/erm options` opens the options panel.
- `/erm falling` toggles falling rescue.
- `/erm flying` toggles flying mount preference.
- `/erm water` toggles underwater mount preference.
- `/erm surface` toggles flying mounts at the water surface.
- `/erm favorites` cycles favorite mode.
- `/erm skyriding` toggles skyriding mounts.
- `/erm flyable` toggles flying preference only in flyable areas.
- `/erm blacklist <mountID>` blacklists a mount.
- `/erm blacklistcurrent` blacklists your active mount.
- `/erm blacklistlast` blacklists the last random mount.
- `/erm unblacklist <mountID>` removes a mount from the blacklist.
- `/erm debug` toggles support/debug commands.

## Known Limitations

- Falling rescue depends on WoW allowing the action at that moment. Spell casts such as Levitate use EasyRandomMount's secure keybind button and only apply when using the actual keybind, not slash commands.
- In combat, EasyRandomMount uses a pre-built secure fallback macro. This is intentionally simpler than the normal out-of-combat random mount logic because addons cannot dynamically change protected actions after combat lockdown starts.
- Repair and auction house mount keybinds detect known service mounts by their Mount Journal names.
- Water-surface detection depends on WoW state such as swimming, flyable area, and the breath timer. Some edge cases may vary by zone.
- The Mount Journal right-click menu is replaced for mount rows so EasyRandomMount can add blacklist support.
- If WoW marks the addon as out of date, run `/dump select(4, GetBuildInfo())` in chat and update `## Interface` in `EasyRandomMount.toc`.
