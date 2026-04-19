# Current State

## Branch

- Active branch: `main`
- Ahead of `origin/main` by 2 commits before this session.

## Recent Progress

- Rewrote `.docs/ai/roadmap.md` with six sequenced milestones (M1–M6) and a populated tiered backlog (Haiku / Sonnet / Opus).
- Added phase briefs under `.docs/ai/phases/`: M1 and M2 in full, M3–M6 as stubs.
- Recorded the 2026-04-19 milestone structure in `.docs/ai/decisions.md`.
- No app or CLI code changed in this session.

## Milestone Snapshot

- **M1 Quality hardening** — next in flight. Blocks 1.0. User-directed for Claude despite `tier3_owner: codex`.
- **M2 1.0 release** — blocked on M1. Execution-only; no new feature work.
- **M3 Menu bar / UX polish** — stub. Post-1.0.
- **M4 Shortcuts / Spotlight depth** — stub. Post-1.0.
- **M5 Automation trigger depth** — stub. Post-1.0.
- **M6 Platform integrations** — stub. Post-1.0. Highest scope.

## Changed Files In Current Session

- `.docs/ai/roadmap.md`
- `.docs/ai/decisions.md`
- `.docs/ai/current-state.md`
- `.docs/ai/next-steps.md`
- `.docs/ai/phases/M1-quality-hardening.md` (new)
- `.docs/ai/phases/M2-1.0-release.md` (new)
- `.docs/ai/phases/M3-menu-bar-ux-polish.md` (new)
- `.docs/ai/phases/M4-shortcuts-spotlight-depth.md` (new)
- `.docs/ai/phases/M5-automation-trigger-depth.md` (new)
- `.docs/ai/phases/M6-platform-integrations.md` (new)

## Current Blockers

- None at the code level.
- The prior release-execution blockers (App Store metadata/submission, `HOMEBREW_TAP_PAT` secret, signed `/Applications` release-checklist pass) are now scoped inside M2 and blocked behind M1.

## Open Questions

- Confirm Claude will plan and execute M1 despite the repo-level `tier3_owner: codex`. User directed this at session start on 2026-04-19; if direction changes, reassign.
- See per-phase `Open questions` sections in `.docs/ai/phases/M1-*.md` and `M2-*.md`.

## Validation / Test Status

- No builds or tests run this session — docs-only changes.

## Notes

- Use `.docs/ai/next-steps.md` as the immediate execution queue.
- Use `.docs/ai/decisions.md` for durable decisions instead of commit history or chat.
- Phase briefs in `.docs/ai/phases/` are the source of truth for milestone scope and exit criteria.
