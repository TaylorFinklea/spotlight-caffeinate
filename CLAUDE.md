# Claude Repository Guide

## Shared AI Workflow

- Treat `docs/ai/` as the cross-assistant source of truth. Prefer those files over chat memory or inferred context.
- Start every session by reading:
  - `docs/ai/roadmap.md`
  - `docs/ai/current-state.md`
  - `docs/ai/next-steps.md`
- End every work session by updating:
  - `docs/ai/current-state.md`
  - `docs/ai/next-steps.md`
  - `docs/ai/decisions.md` when a durable decision, tradeoff, or policy changed
- Use `docs/ai/handoff-template.md` for concise baton-passing notes.
- Keep assistant-specific execution style in this file or `AGENTS.md`, but keep project state and workflow aligned through the shared docs.

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
