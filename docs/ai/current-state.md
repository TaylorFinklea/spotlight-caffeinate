# Current State

## Branch

- Active branch: `main`

## Recent Progress

- Added App Group-based shared storage resolution so the signed app and bundled CLI can sync state again.
- Added one-time migration logic for legacy app and standalone CLI data into the shared container.
- Added standalone CLI warning behavior for unsynced installs.
- Added shared AI handoff workflow docs and aligned repo instructions for both Codex and Claude.

## Changed Files In Current Session

- `AGENTS.md`
- `CLAUDE.md`
- `docs/ai/roadmap.md`
- `docs/ai/current-state.md`
- `docs/ai/next-steps.md`
- `docs/ai/decisions.md`
- `docs/ai/handoff-template.md`

## Current Blockers

- Signed local validation for App Group sync is still pending. The code is in place, but a provisioned signing setup for `group.io.taylorfinklea.spotlightcaffeinate` is still needed for end-to-end runtime verification.

## Open Questions

- None at the moment beyond the pending signed App Group validation.

## Validation / Test Status

- For the shared App Group sync change in `181550e`:
  - `xcodegen generate` passed
  - app Debug build with `CODE_SIGNING_ALLOWED=NO` passed
  - CLI Debug build with `CODE_SIGNING_ALLOWED=NO` passed
  - app test suite with `CODE_SIGNING_ALLOWED=NO` passed
- For the AI handoff docs added in this session:
  - docs-only change
  - no build or test rerun performed after the docs update

## Notes

- Use `docs/ai/next-steps.md` as the immediate execution queue.
- Use `docs/ai/decisions.md` for durable decisions instead of burying them in commit history or chat.
