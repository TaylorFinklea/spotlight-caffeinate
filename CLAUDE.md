# Claude Repository Guide

## Session Workflow

Handoff state lives in `.docs/ai/` — see global `~/CLAUDE.md` for the standard workflow.

## Project Summary

- `Spotlight Caffeinate` is a focused macOS menu bar app and companion CLI for managing `/usr/bin/caffeinate`.
- Keep the product dedicated to `caffeinate` unless the user explicitly asks to broaden scope.
- `project.yml` is the Xcode project source of truth. Run `xcodegen generate` after changing it.

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
