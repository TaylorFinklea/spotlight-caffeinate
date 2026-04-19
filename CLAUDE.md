# Claude Repository Guide

## Session Workflow

Handoff state lives in `.docs/ai/` — see global `~/CLAUDE.md` for the standard workflow.

## Project Summary

- `Spotlight Caffeinate` is a focused macOS menu bar app and companion CLI for managing `/usr/bin/caffeinate`.
- Keep the product dedicated to `caffeinate` unless the user explicitly asks to broaden scope.
- `project.yml` is the Xcode project source of truth. Run `xcodegen generate` after changing it.

## Architecture

Two-target structure sharing Models, Services, and Support code:

```
SpotlightCaffeinate/             # Menu bar app (LSUIElement)
  App/
    SpotlightCaffeinateApp.swift # @main entry, MenuBarExtra scene
    CaffeinateController.swift   # @Observable state manager (@MainActor)
    StatusMenuView.swift         # Main menu bar dropdown
    PresetManagerView.swift      # Preset CRUD
    AutomationManagerView.swift  # Automation rule management
    SettingsView.swift           # App preferences
  Models/
    CaffeinateSnapshot.swift     # Current caffeinate state
    CaffeinatePreset.swift       # Saved presets
    AutomationRule.swift         # Schedule/power/calendar triggers
    PowerMode.swift              # display | system | full
  Services/
    CaffeinateService.swift      # Process lifecycle, presets, session history
    AutomationService.swift      # Rule-based automation triggers
    CaffeinateNotificationService.swift  # Local notifications on session end
    LaunchAtLoginService.swift   # Launch at login
  Intents/                       # App Intents (Shortcuts integration)
  Support/                       # Utilities & formatters

SpotlightCaffeinateCLI/          # Companion CLI
  SpotlightCaffeinateCLI.swift   # @main async, command dispatcher (start/stop/status/watch/presets/automations)

SpotlightCaffeinateTests/        # Unit tests (shares Models/Services)
project.yml                      # xcodegen spec (source of truth)
```

### Patterns

- **Swift 6 `@Observable`** with `@MainActor` for thread-safe UI state.
- **Async/await throughout** — services are fully async.
- **Dual storage contexts**: App and CLI maintain separate persistent state unless CLI is bundled in the app.
- **Post-build script** embeds CLI binary in the app bundle.
- **Code sharing**: Both targets compile Models/, Services/, and Support/ via source paths in `project.yml`.

## Validation Defaults

1. Pull before committing or pushing:
   - `git pull --rebase origin main`
2. If `project.yml` changed:
   - `xcodegen generate`
3. App build:
   - `xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinate -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
4. CLI build if CLI or `project.yml` changed:
   - `xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinateCLI -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
5. Tests:
   - `xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinate -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`
6. Create a small descriptive commit by default.
