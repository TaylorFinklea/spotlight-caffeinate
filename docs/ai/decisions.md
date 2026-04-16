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

## 2026-04-16

### Native keep-awake assertions must be time-bounded and persisted

- The native assertion backend should create IOKit assertions with an explicit timeout derived from the requested `-t` duration instead of relying on in-process bookkeeping to end the session.
- Persist created assertion IDs alongside the session record so a relaunched app or CLI can stop or archive the same keep-awake session cleanly.
- Treat assertion-backed sessions as active until their recorded end time; do not depend on transient in-memory controller state to determine whether a relaunched session is still valid.

### Startup should not probe other apps' container directories

- Do not construct or probe `~/Library/Containers/io.taylorfinklea.spotlightcaffeinate/...` directly during default environment resolution.
- When legacy sandbox storage needs to be inferred, only reuse the current process application-support directory if the process is already running inside that sandbox path.
- This avoids the macOS "would like to access data from other apps" prompt during normal launch.
