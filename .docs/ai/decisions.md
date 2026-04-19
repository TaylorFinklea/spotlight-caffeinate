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

## 2026-03-28

### Apple team `K7CBQW6MPG` is the default local signing team

- `project.yml` now defaults the app and CLI signing path to Apple team `K7CBQW6MPG`.
- The App Group `group.io.taylorfinklea.spotlightcaffeinate` is expected to exist on that team for local signed validation and App Store packaging.

### App Store packaging stops at the archive

- On the current local Xcode toolchain, `xcodebuild -exportArchive` did not expose a usable Mac App Store export path for this app archive.
- The repo App Store packaging script should create `build/SpotlightCaffeinateAppStore.xcarchive` and hand off upload to Xcode Organizer or Transporter.
- Do not treat a local `build/app-store-export` output as part of the required App Store submission flow for this repo.

## 2026-04-02

### Homebrew CLI distribution should use the prebuilt release tarball

- The Homebrew formula for `spotlight-caffeinate-cli` should download `spotlight-caffeinate-cli.tar.gz` from GitHub Releases and install the binary directly.
- Do not point the formula at the repository source tarball or invoke `xcodebuild` on end-user machines for CLI-only installs.
- The repo ships `scripts/install_cli_release.sh` for direct binary installs and `scripts/render_homebrew_cli_formula.sh` to render the expected formula body for the tap update.

### Future tap updates should come from release asset digests

- The repo now includes `.github/workflows/update-homebrew-tap.yml` so published releases can update both the Homebrew cask and formula in `TaylorFinklea/homebrew-tap`.
- That workflow expects a repo secret named `HOMEBREW_TAP_PAT` with permission to push to `TaylorFinklea/homebrew-tap`.
- The workflow should render tap files from published release asset digests rather than recomputing hashes from a fresh local build.

## 2026-04-19

### Milestone structure: hardening → 1.0 → focused depth

- Six sequenced milestones live in `.docs/ai/roadmap.md`: M1 hardening, M2 1.0, M3 menu-bar/UX polish, M4 Shortcuts/Spotlight depth, M5 automation trigger depth, M6 platform integrations.
- M1 is a hard gate on 1.0. CLI integration tests, automation `os.Logger` failure logging, and error-path coverage must land before 1.0.
- M2 is a coordinated 1.0 across App Store, Homebrew (cask + formula), and signed direct-download on the same day. Decoupling channels at 1.0 was explicitly rejected.
- Post-1.0 direction is "focused depth in existing surfaces." No generalization into a shell launcher or multi-tool.
- All four post-1.0 directions are in-scope intent: more automation triggers, menu bar/UX polish, Shortcuts/Spotlight depth, platform integrations. Order after M2 is a working guess and may be re-prioritized.
- Non-goal added: no telemetry or analytics. App Privacy answer stays "No data collected."

### Phase briefs live under `.docs/ai/phases/`

- One short brief per milestone, named `M{N}-{slug}.md`.
- M1 and M2 are written in full; M3–M6 are stubs to be filled in as they become next.
- `tier3_owner` stays `codex` at the repo level, but M1 is user-directed for Claude for the 2026-04-19 session.
