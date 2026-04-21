# Current State

## Branch

- Active branch: `main`
- Ahead of `origin/main` by 11 commits.

## Recent Progress

### M1 — Quality hardening (done)

Six commits landed in order:

- `b25d1c6` — `SPOTLIGHT_CAFFEINATE_STORAGE_ROOT` env-var override for storage paths, tests exercise it hermetically.
- `2330634` — `os.Logger(subsystem: "io.taylorfinklea.spotlightcaffeinate", category: "automation")` wired into all four silent catch sites in `AutomationService`.
- `f6ef40f` — replaced 200 ms `Task.sleep` in the notification enable flow with `NSApplication.didBecomeActiveNotification` observation + 500 ms fallback + fast path for already-active state. `os.Logger(category: "controller")` logs a warning when the timeout fires.
- `30003e7` — 17 error-path tests for `CaffeinateService` + `AutomationService` (invalid preset/minutes, corrupted JSON, calendar denial, invalid automation params, unwritable storage directory).
- `42c1127` — `CLIRunner` integration test harness + `SpotlightCaffeinateTests` → `SpotlightCaffeinateCLI` build-order dep in `project.yml`.
- `f80dee2` — CLI integration tests for non-caffeinate-spawning commands (7 enabled). 5 caffeinate-spawning tests disabled with `.disabled("...")` pointing at a Sonnet backlog item.

Full test suite: **68 tests in 10 suites, 2.6 seconds, green**.

### M2 — 1.0 release (prep landed)

One commit of autonomous prep work:

- `0c9c103` — `CHANGELOG.md` (populated 1.0 entry, date pending), `scripts/release_preflight.sh` (regen + build + test + lint + changelog gate), CHANGELOG enforcement in `scripts/package_signed_release.sh`, refreshed `docs/index.html` with three-channel install section.

The remaining M2 work is user-gated — see `.docs/ai/next-steps.md`.

## Milestone Snapshot

- **M1 Quality hardening** — done.
- **M2 1.0 release** — prep landed; user-gated work remains.
- **M3 Menu bar / UX polish** — stub.
- **M4 Shortcuts / Spotlight depth** — stub.
- **M5 Automation trigger depth** — stub.
- **M6 Platform integrations** — stub.

## Known Limitations

- 5 CLI integration tests are `@Test(.disabled(...))` because Foundation `Process` leaks the test-side pipe write-end into `/usr/bin/caffeinate`, hanging later tests. Fix candidates documented in the Sonnet backlog of `.docs/ai/roadmap.md`.
- App Privacy answer in `docs/app-store-metadata.md` is still a draft; needs to be submitted through App Store Connect.
- `HOMEBREW_TAP_PAT` repo secret is still unset, so `.github/workflows/update-homebrew-tap.yml` will not push to `TaylorFinklea/homebrew-tap` on release publish until configured.

## Changed Files In Current Session

- `.docs/ai/current-state.md`
- `.docs/ai/roadmap.md` (new Sonnet backlog item about re-enabling the disabled CLI tests)
- `.docs/ai/next-steps.md`
- `CHANGELOG.md` (new)
- `SpotlightCaffeinate.xcodeproj/project.pbxproj`
- `SpotlightCaffeinate/App/CaffeinateController.swift`
- `SpotlightCaffeinate/Services/AutomationService.swift`
- `SpotlightCaffeinate/Support/SpotlightCaffeinatePaths.swift`
- `SpotlightCaffeinateTests/AutomationServiceTests.swift`
- `SpotlightCaffeinateTests/CaffeinateServiceTests.swift`
- `SpotlightCaffeinateTests/CLIIntegrationHarness.swift` (new)
- `SpotlightCaffeinateTests/SpotlightCaffeinateCLIIntegrationTests.swift` (new)
- `SpotlightCaffeinateTests/SpotlightCaffeinatePathsTests.swift`
- `docs/index.html`
- `docs/site.css`
- `docs/release-checklist.md`
- `project.yml` (SpotlightCaffeinateTests build-order dependency on SpotlightCaffeinateCLI)
- `scripts/package_signed_release.sh`
- `scripts/release_preflight.sh` (new)

## Current Blockers

- None at the code level.
- Release-execution blockers remain user-owned (see next-steps).

## Manual QA Flagged For User

Two items from M1 need hands-on verification on a signed install before M2 wraps:

1. **C2 — automation logging.** Install the Debug build, corrupt the real App Group `automations.json`, toggle an automation enabled, and run
   `log stream --predicate 'subsystem == "io.taylorfinklea.spotlightcaffeinate" && category == "automation"'`
   to confirm the new error line appears.
2. **C3 — notification activation.** Delete `~/Library/Group Containers/group.io.taylorfinklea.spotlightcaffeinate`, cold-launch the app, toggle notifications on from the menu, confirm the macOS auth prompt appears reliably. `log stream` with `category == "controller"` should NOT show the activation-timeout warning on the happy path.

## Validation / Test Status

- `xcodebuild test` on `SpotlightCaffeinate` scheme: 68 tests across 10 suites pass in ~2.6 seconds.
- `bash -n` passes for every script in `scripts/`.
- No signed build or App Store archive attempted this session.

## Notes

- Use `.docs/ai/next-steps.md` as the immediate execution queue.
- Phase briefs in `.docs/ai/phases/M1-quality-hardening.md` and `.docs/ai/phases/M2-1.0-release.md` are the source of truth for milestone scope and exit criteria.
- `scripts/release_preflight.sh` is the entry point for release-readiness checks before tagging.
