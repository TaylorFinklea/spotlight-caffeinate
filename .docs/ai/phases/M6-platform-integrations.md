# M6 — Platform Integrations

**Status:** stub. Fill in when prior milestones are complete.

## Goal

Surface status and controls outside the menu bar where it makes sense. This is the highest-scope milestone — any item in it should go through its own brainstorm before implementation.

## Candidate work

- Widgets that show active session + time remaining.
- Control Center module.
- Focus mode filter that auto-starts a caffeinate session when a Focus activates.
- Live Activities on compatible hardware.

## Constraints

- Keep the product focused on `caffeinate`. Do not use platform integrations as a wedge to expand scope.
- All items must be App-Store-safe. No private APIs, no entitlements that would block review.
- Sandboxed App Store build still cannot run `/usr/bin/caffeinate`; it uses native IOKit assertions. Any widget or Control Center UI must work with both backends.

## Open questions

- Widgets vs Live Activities priority: which ships first?
- Control Center: is the value a toggle, or a full preset picker?
