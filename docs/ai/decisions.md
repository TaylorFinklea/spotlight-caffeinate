# Decisions

## 2026-03-27

### Shared AI state lives in `docs/ai/`

- `docs/ai/roadmap.md`, `docs/ai/current-state.md`, and `docs/ai/next-steps.md` are the required session-start reads.
- Session-end updates must go to `current-state.md`, `next-steps.md`, and `decisions.md` when relevant.
- Shared docs are the source of truth across assistants; chat memory is not.

### Signed app + bundled CLI share state, standalone CLI may not

- The signed menu bar app and the CLI installed from the app bundle should use an App Group-backed store.
- Standalone/source-built/Homebrew CLI installs may remain independent.
- Independent CLI installs should warn on mutating commands when a sandboxed app install is present.

### Legacy migration favors existing app-managed data

- On first shared-container initialization, prefer sandboxed app presets and automations.
- Carry over an active standalone CLI session if present.
- Merge session and automation history conservatively instead of attempting a full preset/rule reconciliation.
