# AI Roadmap

## Now / Next / Later

Active items. Trim as completed.

### Now (manual QA on a signed install before cutting 1.0)
- Install a signed Debug build into `/Applications`, corrupt `~/Library/Group Containers/group.io.taylorfinklea.spotlightcaffeinate/SpotlightCaffeinate/automations.json`, toggle an automation on, then `log stream --predicate 'subsystem == "io.taylorfinklea.spotlightcaffeinate" && category == "automation"'` should show the new error line.
- Delete `~/Library/Group Containers/group.io.taylorfinklea.spotlightcaffeinate`, cold-launch the app, toggle notifications on, confirm the macOS auth prompt appears reliably and the `category == "controller"` warning does **not** fire on the happy path.
- M3 glyph slice: switch through Bolt fill / Ring / Bolt + Time in Settings; confirm each renders correctly at the system menu bar height, including the mode-dot strip when a session is running.
- M3 pulse: start a 2-minute session with the default 1-minute threshold; confirm the bolt begins fading at ~1:00 remaining and stops on extend/stop. Verify each pulse threshold value (Off / 30s / 1m / 5m).
- M3 app icon: confirm Finder, Dock, Launchpad, and About-window icons all show the new bolt at every preview size.

### Next (M2 user-owned execution queue)
1. Pre-flight on the 1.0.0 cut: `./scripts/release_preflight.sh` — must pass clean.
2. Signed `/Applications` release-checklist pass: build via `./scripts/package_signed_release.sh --team-id K7CBQW6MPG --notary-profile <PROFILE>`, install into `/Applications`, walk through every bullet in `docs/release-checklist.md`.
3. App Store Connect: capture/refresh screenshots (main menu active/idle, presets, automations, settings); set pricing; submit App Privacy answers ("No data collected" — draft in `docs/app-store-metadata.md`); submit App Review notes; build archive via `./scripts/package_app_store_release.sh --team-id K7CBQW6MPG`; upload from Xcode Organizer or Transporter.
4. Homebrew tap automation: add the `HOMEBREW_TAP_PAT` repo secret (GitHub PAT with push rights to `TaylorFinklea/homebrew-tap`); confirm `.github/workflows/update-homebrew-tap.yml` runs on release publish.
5. GitHub release: rebuild CLI tarball with `./scripts/package_cli_release.sh`, tag `v1.0.0`, push, attach `build/SpotlightCaffeinate.zip` and `build/spotlight-caffeinate-cli.tar.gz` to the release.
6. Post-publish verification: `brew install --cask TaylorFinklea/tap/spotlight-caffeinate` installs and launches; `brew install TaylorFinklea/tap/spotlight-caffeinate-cli` installs the CLI; the curl-tarball install path works; App Store listing is live.

### Later
- Keep `.docs/ai/current-state.md`, `.docs/ai/roadmap.md` Now/Next/Later, and `.docs/ai/decisions.md` current at the end of each session.

## Durable Goals

- Ship a reliable macOS menu bar app for starting, stopping, extending, and checking `caffeinate` sessions.
- Maintain a companion CLI that is useful both standalone and when installed from the app bundle.
- Keep Spotlight/App Intents, menu bar UI, and CLI behavior consistent where the product explicitly supports shared state.
- Stay narrowly focused on caffeinate: deepen existing surfaces rather than generalize.

## Milestones

Milestones are sequenced. **M1 blocks 1.0. M2 is the 1.0 launch.** M3–M6 capture post-1.0 focused-depth directions; their relative order is a working guess we can re-prioritize after 1.0 ships.

### M1 — Quality hardening (1.0 gate)

Goal: raise the test and observability floor so 1.0 ships with confidence and does not ship silent regressions.

Exit criteria:
- CLI end-to-end integration tests cover every command (parse → execute → persisted state), including `start`, `stop`, `status`, `extend`, `history`, `presets list`, and every `automations` subcommand. `watch` covered with a cancellation check.
- Automation failures are logged with structured context (rule id, trigger kind, failure reason) through `os.Logger` instead of silently swallowed in `AutomationService`.
- Error-path tests exist for `CaffeinateService` and `AutomationService`: invalid preset names, calendar auth denial, invalid automation parameters, file-permission failures, corrupted JSON recovery.
- Notification enable flow no longer relies on a 200 ms `Task.sleep` to race app activation (`CaffeinateController`).
- Full test suite passes on CI against macOS 26.

### M2 — 1.0 release across all three channels

Goal: a coordinated 1.0 where App Store, Homebrew, and signed direct-download are all live and healthy on the same day.

Exit criteria:
- App Store metadata complete: screenshots captured, pricing set, App Privacy answers submitted ("No data collected"), App Review notes submitted.
- Signed `/Applications` release checklist passes end to end: menu bar, notifications, launch-at-login, bundled CLI sync, Spotlight actions, all automation trigger types.
- App Store archive uploaded via Xcode Organizer or Transporter and approved for sale.
- `HOMEBREW_TAP_PAT` repo secret configured so `.github/workflows/update-homebrew-tap.yml` runs on release publish.
- `CHANGELOG.md` established with 1.0 entry.
- GitHub release tag `v1.0.0` published with both `SpotlightCaffeinate.zip` and `spotlight-caffeinate-cli.tar.gz` assets.
- Homebrew cask and CLI formula both install and run against the published release.
- GitHub Pages site updated with 1.0 install instructions and current screenshots.

### M3 — Menu bar and UX polish

Goal: make the existing UI measurably better without expanding scope.

Status: glyph polish slice done 2026-04-30 (new bolt geometry, three selectable glyph styles, mode dots, configurable near-expiry pulse). Remaining slices below.

Candidate work:
- [x] Menu bar glyph polish: new C3 bolt geometry, selectable styles (boltFill / ring / text), mode dots (1/2/3 = display/system/full), opacity-breath pulse with configurable threshold (Off / 30s / 1m / 5m). Settings UI replaced "Show remaining time" toggle with a Menu Bar Appearance card. App icon regenerated.
- [ ] Global hotkey / keyboard shortcut to start/stop/extend without opening the menu.
- [ ] Accessibility pass: VoiceOver labels, dynamic type, keyboard navigation across all windows.
- [ ] Preset list enhancements: search, grouping, import/export.
- [ ] First-run onboarding tips and empty-state copy.

### M4 — Shortcuts and Spotlight depth

Goal: make Shortcuts/Spotlight a first-class surface for driving the app.

Candidate work:
- Entity types for presets and automations so Shortcuts can iterate and bind to them.
- Parameterized intents (e.g. `StartPreset` with dynamic preset lookup, `ScheduleNextRun`).
- Replace the `PresetRunnerWindowController` foreground-window fallback with a proper `IntentResult` that resolves in-process.
- Discoverability improvements for Spotlight actions; consistent localization of intent dialog strings.

### M5 — Automation trigger depth

Goal: more ways to start a caffeinate session automatically, still inside current scope.

Candidate work:
- App-running trigger (start a session while app X is running).
- Network trigger (connected to SSID, VPN on/off).
- Location trigger.
- Focus filter as a trigger source.
- Quiet hours / do-not-trigger windows applied across all trigger types.

### M6 — Platform integrations

Goal: surface status and controls outside the menu bar where it makes sense.

Candidate work:
- Widgets.
- Control Center module.
- Focus mode filter that auto-starts a caffeinate session.
- Live Activities on compatible hardware.

## Constraints

- Keep the product narrowly focused on `/usr/bin/caffeinate`.
- `project.yml` is the Xcode project source of truth — regenerate with `xcodegen generate` after changes.
- Menu bar app remains sandboxed for App Store submission.
- Signed app + bundled CLI share state via the `group.io.taylorfinklea.spotlightcaffeinate` App Group; standalone CLI installs remain independent with clear user messaging.
- Shared AI docs in `.docs/ai/` are the source of truth for repo state and next actions.

## Non-Goals

- Do not generalize this into a generic automation or shell launcher.
- Do not promise shared state for every unsigned or Homebrew-installed CLI path.
- Do not treat chat history as canonical project state.
- Do not ship telemetry or analytics. The App Privacy answer stays "No data collected."
- Do not bundle features that require non-public entitlements or App-Store-rejection-risk APIs.

## Backlog

> Self-contained items any agent can pick up. First agent to start it executes it. Tier hints are advice, not gating.

### Mechanical (Haiku candidates)

- [ ] Audit repo docs for stale `docs/ai/` references (old path); replace with `.docs/ai/` where they appear in README, AGENTS.md, `docs/release-checklist.md`, `docs/app-store-*`, and any script comments. Do not move the files.
- [ ] Add `NSHumanReadableCopyright` to `SpotlightCaffeinate/Info.plist` via `project.yml` if missing.
- [ ] Add `accessibilityLabel` / `accessibilityHint` to `SpotlightCaffeinate/App/BoltIconView.swift` glyph.
- [ ] Add `accessibilityLabel` on segmented controls and steppers in `SpotlightCaffeinate/App/StatusMenuView.swift`.
- [ ] Add `accessibilityLabel` on preset form fields in `SpotlightCaffeinate/App/PresetManagerView.swift`.
- [ ] Add `accessibilityLabel` on trigger editors in `SpotlightCaffeinate/App/AutomationManagerView.swift`.
- [ ] Verify every script under `scripts/` starts with `#!/usr/bin/env bash` and `set -euo pipefail`; normalize any that diverge.
- [ ] Audit README for macOS version strings — confirm "macOS 26" is consistent across install, notes, and development sections.
- [ ] Add a "Supported macOS versions" line to `README.md` under Install, matching `deploymentTarget: "26.0"` in `project.yml`.

### Architectural (Sonnet candidates)

- [ ] Add structured `os.Logger` logging for `AutomationService` evaluation failures; today errors are silently caught in `Services/AutomationService.swift`. Log rule id, trigger kind, and error. Do not log user data (event titles, calendar names) at info level.
- [ ] Extract the `shouldDiscardLegacyCLIRecord` heuristic in `Services/CaffeinateService.swift` into a named, tested policy helper so its rules are explicit and covered.
- [ ] Introduce a small `Clock` / `DateProvider` protocol in `Support/` and thread it through `CaffeinateService` + `AutomationService`; tests today hand-roll date injection per file, standardize it.
- [ ] Replace the 200 ms `Task.sleep` in the notification enable flow around `CaffeinateController.swift` with an explicit async signal tied to app activation.
- [ ] Write a `CHANGELOG.md` scaffold following Keep a Changelog; wire `package_signed_release.sh` to fail if `MARKETING_VERSION` is not referenced in the changelog.
- [ ] Add `scripts/verify_release_assets.sh` that re-checks a published release's zip + tarball SHA256 and refuses to update the tap if digests disagree.
- [ ] Split the GitHub Pages site (`docs/index.html`, `docs/site.css`) into a minimal landing page with current screenshots, install instructions for all three channels, and links to support/privacy.
- [x] Re-enable the five `@Test(.disabled(...))` integration tests in `SpotlightCaffeinateTests/SpotlightCaffeinateCLIIntegrationTests.swift`. Resolved 2026-04-27: `CLIRunner.run` now redirects stdout/stderr to per-invocation temp files instead of pipes, and both `CLIRunner.run` and `RunningProcess.waitUntilExit` bridge `Process.terminationHandler` through `CheckedContinuation` / `AsyncStream`-backed `Task` instead of `Process.waitUntilExit()`. Pipe ends in `spawn` are also marked `FD_CLOEXEC`. Suite passes in 0.4s with all 12 integration tests green.

### Cross-cutting (needs Opus to scope)

- [ ] Design and implement CLI end-to-end integration tests: spawn the built `spotlight-caffeinate-cli`, point it at an isolated temporary storage context, verify full parse → execute → persisted state for every command. Include `watch` with an explicit cancellation check.
- [ ] Error-path coverage pass across `CaffeinateService` and `AutomationService`: invalid preset names, calendar auth denial, invalid automation parameters, file-permission failures, corrupted JSON recovery. Decide the error-reporting contract for each service.
- [ ] Harden the notification enable flow so the 200 ms sleep can be removed without regressions; may require restructuring `CaffeinateController` state.
- [ ] Audit `CaffeinateController` (553 lines) and split responsibilities into smaller observable view models if it crosses the "too many responsibilities" bar.
- [ ] Design the M4 entity types (`PresetEntity`, `AutomationEntity`) and the set of parameterized intents that replace the current `StartPresetIntent` foreground-window flow.
- [ ] Design M5 trigger-depth architecture: how new trigger kinds plug into `AutomationTrigger`, `AutomationService` evaluation, persistence/migration of existing rules, and UI surfaces in `AutomationManagerView`.
