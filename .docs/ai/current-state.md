# Current State

## Branch

- Active branch: `main`
- Ahead of `origin/main` by 14 commits.

## Recent Progress

### M1 — Quality hardening (done)

Six commits landed in M1; details remain in the previous session's notes
and in the M1 phase brief.

### M2 — 1.0 release (prep landed; version cut and CLI-test deferral retired)

Three further commits since the last session:

- `0c9c103` (prior session) — CHANGELOG, preflight, landing page.
- `b0760d8` (prior session) — handoff doc updates.
- `7b8ee32` — `MARKETING_VERSION` 0.4.0 → 1.0.0, `CURRENT_PROJECT_VERSION`
  4 → 10, `CFBundleShortVersionString` / `CFBundleVersion` regenerated,
  `## [1.0.0] — 2026-04-27` heading promoted in `CHANGELOG.md`.
- `4967b0d` — re-enables the five caffeinate-spawning CLI integration
  tests by switching `CLIRunner.run` to temp-file capture and bridging
  `Process.terminationHandler` through async/await for both `run` and
  `RunningProcess.waitUntilExit`. The Sonnet backlog item that tracked
  this work is now marked `[x]` in `.docs/ai/roadmap.md`.

CLI release tarball was rebuilt locally as a dry run:

- `build/spotlight-caffeinate-cli.tar.gz` (459 KB) contains the Release
  binary plus a `caf` symlink. A local smoke test confirms
  `spotlight-caffeinate-cli status --json` returns the expected idle
  payload.

Full test suite: **all 10 suites green in ~0.6 s**, including all 12
CLI integration tests.

## Milestone Snapshot

- **M1 Quality hardening** — done.
- **M2 1.0 release** — version cut and integration tests re-enabled;
  signing, App Store, Homebrew secret, and tag/push remain user-gated.
- **M3 Menu bar / UX polish** — stub.
- **M4 Shortcuts / Spotlight depth** — stub.
- **M5 Automation trigger depth** — stub.
- **M6 Platform integrations** — stub.

## Known Limitations

- `HOMEBREW_TAP_PAT` repo secret is still unset, so
  `.github/workflows/update-homebrew-tap.yml` will not push to
  `TaylorFinklea/homebrew-tap` on release publish until configured.
- App Privacy answer in `docs/app-store-metadata.md` is still a draft;
  needs to be submitted through App Store Connect.

## Changed Files In Current Session

- `.docs/ai/current-state.md`
- `.docs/ai/next-steps.md`
- `.docs/ai/decisions.md`
- `.docs/ai/roadmap.md` (Sonnet backlog item closed)
- `CHANGELOG.md` (1.0.0 dated 2026-04-27)
- `project.yml` (version bump to 1.0.0 / 10)
- `SpotlightCaffeinate.xcodeproj/project.pbxproj` (regenerated)
- `SpotlightCaffeinate/Info.plist` (regenerated)
- `SpotlightCaffeinateTests/CLIIntegrationHarness.swift` (temp-file
  capture, terminationHandler bridge, FD_CLOEXEC on `spawn` pipes)
- `SpotlightCaffeinateTests/SpotlightCaffeinateCLIIntegrationTests.swift`
  (five `.disabled` annotations removed)
- `build/spotlight-caffeinate-cli.tar.gz` (1.0.0 dry-run tarball, not
  attached to a release tag yet)

## Current Blockers

- None at the code level.
- Release-execution blockers remain user-owned (see next-steps).

## Manual QA Flagged For User

Two items from M1 still need hands-on verification on a signed install
before M2 wraps:

1. **Automation logging.** Install the Debug build, corrupt the real
   App Group `automations.json`, toggle an automation enabled, and run
   `log stream --predicate 'subsystem == "io.taylorfinklea.spotlightcaffeinate" && category == "automation"'`
   to confirm the new error line appears.
2. **Notification activation.** Delete
   `~/Library/Group Containers/group.io.taylorfinklea.spotlightcaffeinate`,
   cold-launch the app, toggle notifications on from the menu, confirm
   the macOS auth prompt appears reliably. `log stream` with
   `category == "controller"` should NOT show the activation-timeout
   warning on the happy path.

## Validation / Test Status

- `xcodebuild test` on `SpotlightCaffeinate` scheme: 10 suites green in
  ~0.6 s. All 12 CLI integration tests pass (none disabled).
- `bash -n` passes for every script in `scripts/`.
- `scripts/package_cli_release.sh` produces a working binary tarball
  locally; smoke test against the extracted binary returns the
  expected JSON status payload.
- No signed build or App Store archive attempted this session.
- `scripts/release_preflight.sh` was not re-run after the harness fix
  landed; rerun before tagging to capture the green state in CI.

## Notes

- Use `.docs/ai/next-steps.md` as the immediate execution queue.
- Phase briefs in `.docs/ai/phases/M1-quality-hardening.md` and
  `.docs/ai/phases/M2-1.0-release.md` are the source of truth for
  milestone scope and exit criteria.
- `scripts/release_preflight.sh` is the entry point for
  release-readiness checks before tagging.
