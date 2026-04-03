# Repository Notes

## AI Handoff Workflow

- Treat `docs/ai/` as the shared source of truth across assistants. Do not rely on chat memory for project continuity.
- Start every session by reading:
  - `docs/ai/roadmap.md`
  - `docs/ai/current-state.md`
  - `docs/ai/next-steps.md`
- End every work session by updating:
  - `docs/ai/current-state.md`
  - `docs/ai/next-steps.md`
  - `docs/ai/decisions.md` when a durable decision, tradeoff, or policy changed
- Use `docs/ai/handoff-template.md` as the default shape for session-end handoff notes.
- If shared AI docs conflict with stale chat context, follow the docs and bring them up to date.

## Purpose

`Spotlight Caffeinate` is a focused macOS menu bar app for running `/usr/bin/caffeinate` through App Intents and Spotlight. Keep it dedicated to `caffeinate` unless the user explicitly asks to generalize it. Do not turn it into a generic terminal-command launcher by default.

## Architecture

- `SpotlightCaffeinate/App/SpotlightCaffeinateApp.swift`
  - App entry point.
  - Uses `MenuBarExtra` and `LSUIElement` for a menu-bar-only utility.
  - The menu bar label reads from `controller.currentTime` so the countdown can tick live.

- `SpotlightCaffeinateCLI/SpotlightCaffeinateCLI.swift`
  - Companion terminal interface for environments where the app cannot live in `/Applications`.
  - Supports `start`, `stop`, `status`, and `watch`.
  - Reuses the same `CaffeinateService` and `CaffeinateSnapshot` types as the app.

- `SpotlightCaffeinate/App/CaffeinateController.swift`
  - MainActor observable UI controller.
  - Polls the service every second.
  - `currentTime` is intentionally updated every second to drive live countdown rendering even when the snapshot itself is unchanged.

- `SpotlightCaffeinate/Services/CaffeinateService.swift`
  - Actor that launches and stops `/usr/bin/caffeinate`.
  - Launches `caffeinate -disu -t <seconds>` so the app keeps the display awake and holds the broader sleep-prevention assertions users expect.
  - Persists shared state to `~/Library/Application Support/SpotlightCaffeinate/state.json`.
  - Schedules and cancels completion notifications through the notification service so all entry points behave consistently.
  - Important: use `URL.path` (property), not `URL.path()` (method), for filesystem calls. `path()` percent-encodes spaces and previously caused the app to think active runs were missing.

- `SpotlightCaffeinate/Services/CaffeinateNotificationService.swift`
  - Owns the local notification preference and schedules the completion alert.
  - Notifications are opt-in. Turning the toggle on should be the moment macOS asks for permission.
  - Enabling notifications should also send an immediate confirmation banner so the user can verify alerts are working.

- `SpotlightCaffeinate/App/NotificationCenterDelegate.swift`
  - Installs the app as the `UNUserNotificationCenter` delegate.
  - Foreground notifications should still present as banners and play sound.

- `SpotlightCaffeinate/Services/LaunchAtLoginService.swift`
  - Wraps `SMAppService.mainApp` for the menu bar app's launch-at-login toggle.
  - Treat `.requiresApproval` as a pending-enabled state and surface guidance in the menu UI.
  - This path depends on a signed app build; unsigned/debug builds may report that launch at login is unavailable.

- `SpotlightCaffeinate/Models/CaffeinateSnapshot.swift`
  - Pure snapshot model.
  - Time-derived helpers accept an explicit `Date` so the UI can render against a live clock.

- `SpotlightCaffeinate/Intents/CaffeinateIntents.swift`
  - App Intents for start, stop, and status.
  - Spotlight actions should return visible snippet cards, not just background dialogs, so status is obvious when invoked from Spotlight.
  - Keep shortcut phrases simple. App Intents metadata export rejected the integer duration inside the shortcut phrase, so duration is collected as a prompted parameter instead.

- `project.yml`
  - Source of truth for the Xcode project.
  - After editing project settings, run `xcodegen generate`.

- `scripts/install_cli.sh`
  - Builds the CLI target and copies `spotlight-caffeinate-cli` into a destination directory.
  - Defaults to `~/.local/bin`.

- `scripts/package_cli_release.sh`
  - Builds the CLI target in `Release`.
  - Packages `spotlight-caffeinate-cli` as `build/spotlight-caffeinate-cli.tar.gz`.
  - Prints the tarball SHA256 for optional direct CLI distribution.

- `scripts/install_cli_release.sh`
  - Downloads the prebuilt CLI tarball from GitHub Releases.
  - Installs `spotlight-caffeinate-cli` and the `caf` alias without requiring `xcodebuild` on the destination machine.

- `scripts/render_homebrew_cli_formula.sh`
  - Renders the expected binary-based Homebrew formula body for the CLI release asset.
  - Defaults to the current `MARKETING_VERSION` and can read the SHA256 from `build/spotlight-caffeinate-cli.tar.gz`.

- `scripts/render_homebrew_cask.sh`
  - Renders the expected Homebrew cask body for the signed app release artifact.
  - Defaults to the current `MARKETING_VERSION` and can read the SHA256 from `build/SpotlightCaffeinate.zip`.

- `scripts/package_signed_release.sh`
  - Archives and exports a Developer ID signed release build.
  - Optionally notarizes and staples the app when a `notarytool` keychain profile is provided.

- `scripts/configure_notarytool_profile.sh`
  - Stores reusable `notarytool` credentials in the keychain.

## Change Workflow

1. Pull before committing or pushing:
   - `git pull --rebase origin main`
2. If `project.yml` changed:
   - `xcodegen generate`
3. Verify the app builds:
   - `xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinate -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
4. If the CLI changed or `project.yml` changed, verify the CLI builds too:
   - `xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinateCLI -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
5. Verify tests:
   - `xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinate -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`
6. Create a small descriptive commit.

## Release Workflow

When a source change should ship to users:

1. Bump `MARKETING_VERSION` and `CFBundleShortVersionString` in `project.yml`.
2. Run `xcodegen generate`.
3. Build and zip the unsigned app when you only need a local/dev artifact:
   - `./scripts/package_release.sh`
4. For end-user direct downloads, build the signed artifact instead:
   - `./scripts/package_signed_release.sh --team-id <TEAM_ID> --notary-profile <PROFILE>`
5. Build the CLI release artifact:
   - `./scripts/package_cli_release.sh`
6. Create a GitHub release tag like `v0.4.0` with:
   - `build/SpotlightCaffeinate.zip`
   - `build/spotlight-caffeinate-cli.tar.gz`
7. Update the Homebrew tap repo `TaylorFinklea/homebrew-tap`:
   - `Casks/spotlight-caffeinate.rb`
   - `Formula/spotlight-caffeinate-cli.rb`
   - set the new `version`
   - set the cask `sha256` from `SpotlightCaffeinate.zip`
   - set the formula URL to `https://github.com/TaylorFinklea/spotlight-caffeinate/releases/download/v<TAG>/spotlight-caffeinate-cli.tar.gz`
   - set the formula `sha256` from `build/spotlight-caffeinate-cli.tar.gz`
   - install the binary directly in the formula instead of running `xcodebuild`
8. Use `docs/release-checklist.md` for the signed `/Applications` validation pass before announcing the release.

## Distribution Notes

- Homebrew distribution uses both a cask and a formula:
  - `brew install --cask TaylorFinklea/tap/spotlight-caffeinate`
  - `brew install TaylorFinklea/tap/spotlight-caffeinate-cli`
- `scripts/package_release.sh` is still the unsigned packaging path for local/dev builds.
- Release builds intended for end users should prefer `scripts/package_signed_release.sh`.
- CLI-only Homebrew installs use the `spotlight-caffeinate-cli` formula in `TaylorFinklea/homebrew-tap`.
- Unsigned artifacts may still need quarantine removal after install:
  - `xattr -dr com.apple.quarantine "/Applications/Spotlight Caffeinate.app"`
