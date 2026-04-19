# M4 — Shortcuts and Spotlight Depth

**Status:** stub. Fill in when M3 is complete or deprioritized past M4.

## Goal

Make Shortcuts/Spotlight a first-class surface for driving the app.

## Candidate work

- `PresetEntity` and `AutomationEntity` `AppEntity` types so Shortcuts can iterate and bind to them.
- Parameterized intents: `StartPreset` with dynamic preset lookup, `ScheduleNextRun`, `ToggleAutomation`.
- Replace the `PresetRunnerWindowController` foreground-window fallback with a proper `IntentResult` that resolves in-process (no window opens, no focus steal).
- Discoverability improvements for Spotlight actions. Consistent localization of intent dialog strings via `CaffeinateIntentMessageFormatter`.

## Not in scope

- Changes to CLI command surface.
- Menu-bar UI changes beyond what is required for parity.

## Open questions

- How do we want Shortcuts to behave when the app is not running — launch it in the background, or fail with a dialog?
- Should parameterized intents be able to create new presets, or only run existing ones?
