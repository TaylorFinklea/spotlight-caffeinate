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

## 2026-04-20

### M1 integration tests: 5 caffeinate-spawning tests deferred

- Foundation `Process` leaks the test-side `Pipe` write-end into child processes (most visibly `/usr/bin/caffeinate`). The grandchild keeps the pipe open past the CLI's own exit, so the test harness's next `readabilityHandler`-backed read hangs.
- Attempted fix inside the CLI (closing inherited non-stdio fds at startup) broke Swift runtime fds (GCD, `os.Logger`) and made basic status tests hang instead.
- Decision: ship 7 passing integration tests now and defer the 5 caffeinate-spawning ones as `@Test(.disabled(...))` with an explicit pointer to the Sonnet backlog item. Each disabled test still passes in isolation; only the suite-order hang is deferred.
- Fix candidates captured in the backlog: mark the test-side `Pipe` write-end `FD_CLOEXEC` before `process.run()`, or move `SubprocessCaffeinateProcessController` to `posix_spawn` with `POSIX_SPAWN_CLOEXEC_DEFAULT`.

### CHANGELOG.md is a hard gate for signed releases

- `CHANGELOG.md` follows Keep a Changelog. Every release tag must have a matching `## [X.Y.Z]` heading.
- `scripts/package_signed_release.sh` and `scripts/release_preflight.sh` both fail fast if the current `MARKETING_VERSION` has no changelog entry.
- Intent: prevent accidental tagging without a user-facing release note, and make the changelog the single source of truth for "what changed for end users."

## 2026-04-27

### CLI integration test harness uses temp files + `terminationHandler`, not pipes + `waitUntilExit`

- `CLIRunner.run` now redirects the CLI's stdout/stderr to per-invocation temp files instead of `Pipe`. Foundation's `Process` does not fully release the parent's copy of a pipe write end after `run()`, which kept the test process itself a writer on the pipe and prevented EOF on the read end after the CLI exited.
- Both `CLIRunner.run` and `RunningProcess.waitUntilExit` now bridge `Process.terminationHandler` through `CheckedContinuation` (run) or an `AsyncStream`-backed `Task` (spawn). `Process.waitUntilExit()` was observed to block indefinitely in the xctest harness even after the child process had terminated; the termination handler fires reliably.
- `spawn` (used by the streaming `watch` test) keeps a `Pipe` but additionally marks both pipe ends `FD_CLOEXEC` so `/usr/bin/caffeinate` and similar grandchildren cannot inherit them.
- Result: all five previously `.disabled(...)` integration tests run cleanly in suite order; full suite is green at 0.6 s.
