# Retail 12.1.5 compatibility audit

Reviewed on 2026-10-23 for addon version 1.1.24. Scope: Core.lua,
Options.lua, MountJournal.lua, bindings and addon metadata.

## Findings and fixes

- Item ownership uses C_Item.GetItemCount. The old global is only called if it
  exists. The reported IsItemOwned error at line 192 matches the pre-1.1.22
  implementation, not the currently shipped implementation.
- C_Item.GetItemCooldown returns a boolean enableCooldownTimer. Accept true
  for Retail and 1 for the legacy API; reject cooldowns and disabled items.
- Uncached item names/icons and invalid spell icons can return nil. The options
  UI no longer calls removed global APIs when a modern API returns nil.
- Aura reads stop before calling restricted APIs when ShouldAurasBeSecret is
  true. Aura IDs and names are checked for secret values before table indexing
  or string operations. Unknown water-breathing state preserves underwater
  preference for submerged players without a breath timer.
- UNIT_AURA is registered for player only, avoiding comparisons of potentially
  secret unit tokens in the event payload.
- Protected button attributes are only updated outside lockdown. Combat macros
  stay prepared on the buttons; entering combat does not rewrite attributes.
  Settings changed during lockdown take effect after PLAYER_REGEN_ENABLED.
- Insecure slash-command mount paths stop before combat dismount/summon calls.
- Combat spells use combat/nomounted conditions before the dismount command.
  The unsupported falling condition was removed. Slow Fall/Levitate now self
  cast on a combat key press even when the player is not falling.
- Lua click callbacks follow ActionButtonUseKeyDown, matching the secure
  template's active edge instead of running the mount action twice.
- The journal uses Menu.ModifyMenu for MENU_MOUNT_COLLECTION_MOUNT. Blizzard
  retains its row scripts, mount actions and favorite actions. Drag-button
  owners resolve their mount through their parent row.
- GetMouseFoci returns a table; the debug command no longer wraps it again.

## Source checks

Blizzard-generated API definitions and Blizzard UI code, retrieved from the
live source mirror on the review date:

- [Item APIs](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
- [Spell APIs](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
- [Spellbook APIs](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua)
- [Mount journal APIs](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MountJournalDocumentation.lua)
- [Unit APIs](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Aura APIs and event secrecy](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
- [Secret predicates](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)
- [Secure action implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua)
- [Native mount context menu](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Collections/Mainline/Blizzard_MountCollection.lua)
- [Menu extension implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Menu/Menu.lua)

Mount metadata, item cooldown/count/usability and the player swimming/falling
queries used here have no secret-return annotations in those definitions.
SecretArguments annotations describe accepted arguments, not secret results.

## Validation and limits

Run `lua tests/compatibility.lua` from the repository root using Lua 5.1.
The regression harness loads all three shipped Lua files with modern APIs
present and deprecated item/spell globals absent. It tests boolean and legacy
numeric item cooldown flags, missing/uncached APIs, secret-aura early exits,
water-breathing mount pools, both key-down preferences, protected attribute
writes during simulated combat, deferred settings, player aura events, menu
owners and the installed-version command.

This is a mocked API test, not an emulation of WoW's taint tracking or secure
execution. In-game verification remains required: restart WoW after installing,
check `/erm version`, try all three bindings mounted/unmounted and in/out of
combat, falling items and spells, water breathing and surface swimming, and
the journal menu with and without filters. Test combat option changes during
combat and after leaving it. No in-game taint-free guarantee is implied.
