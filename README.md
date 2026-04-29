# EasyRandomMount

EasyRandomMount is a World of Warcraft addon that gives you one smart random mount keybind.

It can prefer flying mounts, use water mounts underwater, trigger falling rescue spells/items, respect Blizzard Mount Journal favorites, and exclude mounts you never want through a blacklist.

## Features

- Random mount keybind with automatic dismount.
- Flying, water, skyriding, and water-surface mount preferences.
- Falling rescue list for spells and items such as Slow Fall, Levitate, Glide, and similar tools.
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

- Falling rescue depends on WoW allowing the spell or item at that moment. Combat, the global cooldown, class restrictions, missing items, or zone rules can still block it.
- Water-surface detection depends on WoW state such as swimming, flyable area, and the breath timer. Some edge cases may vary by zone.
- The Mount Journal right-click menu is replaced for mount rows so EasyRandomMount can add blacklist support.
- If WoW marks the addon as out of date, run `/dump select(4, GetBuildInfo())` in chat and update `## Interface` in `EasyRandomMount.toc`.
