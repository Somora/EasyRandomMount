# Changelog

## 1.1.16

- Fixed a Druid Travel Form taint error by tracking movement through safe player movement events instead of comparing `GetUnitSpeed()` in the secure click path.

## 1.1.15

- Added a secure Druid Travel Form fallback when moving or when no usable mount is available.

## 1.1.14

- Added an option and slash command to disable class movement abilities in combat.
- Added mount pool caching with automatic invalidation when relevant mount, zone, level, blacklist, or preference state changes.
- Removed unexpected movement combat fallback spells such as Blink, Roll, Fel Rush, Burning Rush, Gust of Wind, Angelic Feather, and Heroic Leap.

## 1.1.13

- Updated the TOC interface version for WoW 12.0.7.

## 1.1.12

- Filtered out character-hidden mounts from random, repair, and auction house pools to avoid faction/class-restricted mount errors.

## 1.1.11

- Skipped slow novelty turtle mounts, such as Riding Turtle and Sea Turtle, in the normal random mount pool.
- Prioritized Grand Expedition Yak for the repair mount keybind whenever it is available.

## 1.1.10

- Throttled repeated mount failure chat messages when mounting is blocked, unavailable, or disallowed.

## 1.1.9

- Reduced falling rescue chat spam by staying quiet when no configured rescue spell is known and no configured rescue item is owned, while throttling temporary unusable/combat messages.

## 1.1.8

- Fixed mounted combat dismounting by registering secure keybind buttons for both key-down and key-up clicks and adding explicit LeftButton secure attributes.

## 1.1.7

- Fixed out-of-combat dismounting by simplifying the secure dismount macro and improving mounted detection.

## 1.1.6

- Improved combat dismount reliability by keeping secure dismount macros ready on the random, repair, and auction house keybinds.
- Migrated repair and auction house keybinds to secure click buttons so they can safely dismount while mounted in combat.

## 1.1.5

- Simplified combat fallback macros by removing fragile `known:` conditions and improving class detection. This should prevent wrong-class spell error messages.

## 1.1.4

- Fixed underwater mount priority for low-level characters by allowing underwater mounts to win before the level 1-9 chauffeured mount override.
- Fixed combat fallback macro conditions to use spell IDs for `known:` checks, preventing wrong-class spell attempts.
- Fixed mage combat fallback by trying Slow Fall while falling and avoiding Blink while falling.
- Relaxed falling rescue spell detection to use known spells instead of generic usability checks, making self-targeted spells like Slow Fall more reliable.

## 1.1.3

- Added a low-level mount override. Characters from level 1 through 9 now only use chauffeured mounts for the random mount keybind.

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
