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
- The App Group `group.dev.finklea.spotlightcaffeinate` is expected to exist on that team for local signed validation and App Store packaging.

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

## 2026-04-30

### M3 logo redesign keeps the bolt metaphor and ships an original shape

- Apple's SF Symbols license forbids using SF Symbols "in any logos or icons used to represent your company, product, or app or as part of your trademark or trade name." The bolt in `BoltIconView` serves as both the menu bar glyph and the app icon, so it functions as the brand mark — using `bolt.fill` as the source path would violate that clause.
- The replacement is the "C3 — Bold geometric bolt" shape from the brainstorming session: same lightning-bolt metaphor, balanced proportions, rounded line joins/caps via a same-color stroke overlay so the corners read as designed rather than hand-drawn.
- SF Symbols remain fine for in-app UI elsewhere (settings rows, picker icons, etc.); the restriction is specifically the brand mark.

### Menu bar glyph style is user-selectable; mode encoding is geometric, not chromatic

- New `GlyphStyle` enum (`boltFill` / `ring` / `text`) drives the menu bar glyph; default is `.boltFill` for new users, with one-shot migration mapping legacy `showMenuBarTime=true` to `.text`.
- The legacy "Show remaining time" toggle was removed from Settings. `GlyphStyle.text` subsumes the same UX (small bolt + remaining-time text) and the picker is the single way to opt in.
- Mode (display / system / full) is signalled by 1/2/3 dots beneath the glyph, rendered into the same `NSImage` as the glyph. No color encoding because the menu bar glyph renders as a template image and macOS would discard color anyway.
- Dots are visible only while a session is running; idle state shows just the bolt outline. Image height grows by ~22% when dots are present so the bolt stays at its full menu-bar size.

### Near-expiry pulse is a controller-driven cosine breath, not a SwiftUI animation

- `MenuBarExtra` template images do not animate via SwiftUI's `.animation(...)` modifier reliably — macOS treats the rendered image as static. The pulse is driven by `CaffeinateController.pulseOpacity`, updated every 200 ms by a dedicated task that quantises the breath into 8 cosine steps over a ~1.6 s loop.
- `SpotlightCaffeinateApp` applies `.opacity(controller.pulseOpacity)` to the whole `MenuBarGlyphView`, so the alpha is baked in to the rendered output before macOS tints it.
- Pulse fires when `PulseThreshold.shouldPulse(remainingSeconds:)` is true. Threshold options: Off / 30 s / 1 min / 5 min, persisted via `UserDefaults`. Default is 1 min.

## 2026-05-05

### Developer ID + App Sandbox + App Group requires an embedded provisioning profile

- The signed v1.0.0 build was notarized successfully and Gatekeeper accepted it (`source=Notarized Developer ID`), but every launch attempt was killed by macOS with `taskgated-helper: Disallowing ... because no eligible provisioning profiles found` (POSIX error 163, "Launchd job spawn failed"). amfid logged `"No matching profile found"` against `com.apple.developer.team-identifier`.
- Cause: `com.apple.security.application-groups` is a team-restricted entitlement. For non-MAS distribution macOS requires an embedded Developer ID provisioning profile that explicitly authorises the App Group for the team's Developer ID Application certificate. v0.4.0 never tripped this because it didn't have App Group.
- Fix: at Apple Developer portal, create a **Distribution → Developer ID** provisioning profile bound to `dev.finklea.spotlightcaffeinate`, pinned to the K7CBQW6MPG Developer ID Application cert, with App Groups capability enabled. Embed the downloaded `.provisionprofile` into the bundle as `Contents/embedded.provisionprofile`, then re-codesign + notarize + staple.
- The Apple Development "Mac Team Provisioning Profile" that Xcode auto-generates for archive builds is **not** a valid replacement; it is associated with Apple Development certs only and amfid rejects it for Developer ID-signed binaries.

### `package_signed_release.sh`'s exportArchive path is broken on the current Xcode toolchain

- The automatic-signing archive uses an Apple Development certificate from whichever team the developer's Apple ID is on (in this case, the personal team N8SUK4L228) while the entitlements declare K7CBQW6MPG. Xcode 26 then refuses `xcodebuild -exportArchive -exportOptionsPlist ... method=developer-id` with `expected one {} but found developer-id`, meaning zero valid distribution methods.
- Workaround for the 1.0.0 cut: copy the archived `.app` aside, re-codesign it manually with `codesign --force --options runtime --timestamp --sign "Developer ID Application: Taylor Finklea (K7CBQW6MPG)" --entitlements <entitlements>` (sign the bundled CLI first, then the wrapper), zip via `/usr/bin/ditto -c -k --keepParent`, submit to `notarytool`, and `stapler staple`.
- The script should be updated to do this manually instead of relying on `exportArchive`. See backlog.

## 2026-05-06

### Bundle identifier renamed from `io.taylorfinklea.*` to `dev.finklea.*`

- `io.taylorfinklea.spotlightcaffeinate` was always a placeholder reverse-DNS for a domain that wasn't owned. The user's actual domain is `finklea.dev`, so the canonical bundle ID is `dev.finklea.spotlightcaffeinate` (CLI: `dev.finklea.spotlightcaffeinate.cli`; App Group: `group.dev.finklea.spotlightcaffeinate`).
- This is a clean break: the broken v1.0.0 GitHub release and tag were deleted, the changelog re-dated, and the new Apple Developer App ID will be registered against the new bundle ID. There is no migration path because there were no successful installs of the old v1.0.0 (signed app failed to launch — see prior entry).
- Touched: `project.yml`, both `.entitlements` files, `SpotlightCaffeinatePaths.swift`, `Logger` subsystems in `CaffeinateController` / `AutomationService` / `CaffeinateNotificationService`, two `notificationIdentifier` constants in the notification service, and `SpotlightCaffeinatePathsTests` fixture paths. The Homebrew tap repo (`TaylorFinklea/homebrew-tap`) and GitHub-Pages support/privacy URLs (`taylorfinklea.github.io/...`) were left as-is — those track GitHub username/handles, not the app bundle namespace.
- After this rename, the Developer Apple ID work happens against the new bundle ID: the Distribution → Developer ID provisioning profile must be created for `dev.finklea.spotlightcaffeinate` (with App Groups capability and `group.dev.finklea.spotlightcaffeinate` enabled), and the App Store Connect record needs to be re-created (the old one was for the placeholder bundle ID and never had a build uploaded).

### v1.0.0 cut succeeded with manual codesign + embedded Developer ID profile

- Working sequence (now captured in `scripts/package_signed_release.sh`):
  1. `xcodebuild ... -archivePath build/SpotlightCaffeinate.xcarchive ... -allowProvisioningUpdates DEVELOPMENT_TEAM=K7CBQW6MPG archive` — same archive command as before.
  2. Copy the archived `.app` from `build/SpotlightCaffeinate.xcarchive/Products/Applications/` to `build/Export/`.
  3. `cp <profile>.provisionprofile build/Export/.../Contents/embedded.provisionprofile`.
  4. `codesign --force --options runtime --timestamp --sign K7CBQW6MPG --entitlements <CLI ent> <bundled CLI binary>`.
  5. `codesign --force --options runtime --timestamp --sign K7CBQW6MPG --entitlements <app ent> <app bundle>`.
  6. `codesign --verify --deep --strict --verbose=2`, `ditto -c -k --keepParent`, `xcrun notarytool submit ... --keychain-profile spotlight-caffeinate-notarytool --wait`, `xcrun stapler staple`, `spctl --assess`, re-zip with stapled bundle.
- Critical detail: the bundled CLI must be signed BEFORE the wrapper, so the wrapper signature seals over the new CLI signature and the embedded profile. Skipping the embed step or signing the wrapper before the CLI both reproduce the v1.0.0-first-cut amfid rejection.
- `codesign --sign K7CBQW6MPG <path>` resolves the team's Developer ID Application identity from the keychain automatically (no need to spell out the full "Developer ID Application: Taylor Finklea (K7CBQW6MPG)" string).
- The `--keychain-profile spotlight-caffeinate-notarytool` is the notarytool profile name set up via `xcrun notarytool store-credentials` on this machine. It is keychain-local; new machines need `scripts/configure_notarytool_profile.sh` first.
- All three install paths verified post-publish: cask launches without amfid rejection, formula CLI runs, curl-tarball CLI runs.
