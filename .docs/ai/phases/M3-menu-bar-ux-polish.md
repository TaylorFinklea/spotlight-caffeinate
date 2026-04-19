# M3 — Menu Bar and UX Polish

**Status:** stub. Fill in when M1+M2 are complete.

## Goal

Measurably improve the existing UI without expanding product scope.

## Candidate work

- Global hotkey / keyboard shortcut to start/stop/extend without opening the menu bar dropdown.
- Accessibility pass: VoiceOver labels, dynamic type, keyboard navigation across all windows (status menu, presets, automations, settings, preset runner).
- Richer progress visualization in the menu bar glyph — extend `BoltIconView`.
- Preset list enhancements: search, grouping, import/export.
- First-run onboarding tips and empty-state copy.

## Not in scope

- New automation triggers (that is M5).
- New Shortcuts intents (that is M4).
- Widgets / Control Center (that is M6).

## Open questions

- Is the global hotkey a per-preset shortcut or a single global start/stop toggle?
- Import/export format: JSON file, or keychain-synced via iCloud?
