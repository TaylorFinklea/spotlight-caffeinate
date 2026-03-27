# AI Roadmap

## Durable Goals

- Ship a reliable macOS menu bar app for starting, stopping, and checking `caffeinate`.
- Maintain a companion CLI that is useful both standalone and when installed from the app bundle.
- Keep Spotlight/App Intents, menu bar UI, and CLI behavior consistent where the product explicitly supports shared state.
- Finish App Store and direct-download release readiness without turning the app into a generic command runner.

## Current Milestones

- Shared-state architecture:
  - Signed app and bundled CLI should share one App Group-backed store.
  - Standalone CLI installs may remain independent with clear user messaging.
- Release readiness:
  - Validate signed App Group builds end to end.
  - Finalize App Store metadata, screenshots, and submission flow.
- Assistant continuity:
  - Keep `docs/ai/` current so work can be handed cleanly between assistants.

## Constraints

- Keep the product narrowly focused on `/usr/bin/caffeinate`.
- `project.yml` is the Xcode project source of truth.
- Menu bar app remains sandboxed for App Store submission.
- Shared AI docs are the source of truth for repo state and next actions.

## Non-Goals

- Do not generalize this into a generic automation or shell launcher by default.
- Do not promise shared state for every unsigned or Homebrew-installed CLI path.
- Do not treat chat history as canonical project state.
