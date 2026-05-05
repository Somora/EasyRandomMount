# Changelog

## 1.1.2

- Removed Brutosaur mounts from the repair mount keybind pool. They are now only detected for the auction house mount keybind.

## 1.1.1

- Removed the separate falling spell toggle. Falling rescue now uses the configured spell/item priority list directly through the secure keybind path.

## 1.1.0

- Added separate keybinds and slash commands for repair mounts and auction house mounts.
- Added service mount detection for Traveler's Tundra Mammoth, Grand Expedition Yak, Mighty Caravan Brutosaur, and Trader's Gilded Brutosaur.
- Reworked the main random mount keybind to use a secure action button, matching the safe pattern used by LiteMount.
- Added secure falling rescue support for spells and items through the main keybind path.
- Added a secure combat fallback macro for class movement/falling tools where Blizzard allows them.
- Prevented random mount fallback attempts while falling when no rescue action is available.
- Avoided protected-action errors from direct spell casting APIs.

## 1.0.1

- Fixed dismount behavior while in combat. EasyRandomMount now attempts to dismount first if you are already mounted, and only blocks summoning a new mount while in combat.

## 1.0.0

- Added smart random mount keybind behavior.
- Added automatic dismount when already mounted.
- Added flying, water, skyriding, flyable-area, and water-surface mount preferences.
- Added falling rescue support with configurable spell/item priority.
- Added Blizzard Mount Journal favorite modes: all mounts, prefer favorites, and only favorites.
- Added mount blacklist support through options, slash commands, and Mount Journal right-click menu.
- Added scrollable blacklist options page.
- Added clearer messages when mounting is temporarily blocked by the game.
- Added optional debug commands for support.
