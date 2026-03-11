# Repository Notes

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
  - Persists shared state to `~/Library/Application Support/SpotlightCaffeinate/state.json`.
  - Schedules and cancels completion notifications through the notification service so all entry points behave consistently.
  - Important: use `URL.path` (property), not `URL.path()` (method), for filesystem calls. `path()` percent-encodes spaces and previously caused the app to think active runs were missing.

- `SpotlightCaffeinate/Services/CaffeinateNotificationService.swift`
  - Owns the local notification preference and schedules the completion alert.
  - Notifications are opt-in. Turning the toggle on should be the moment macOS asks for permission.

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
5. Create a small descriptive commit.

## Release Workflow

When a source change should ship to users:

1. Bump `MARKETING_VERSION` and `CFBundleShortVersionString` in `project.yml`.
2. Run `xcodegen generate`.
3. Build and zip the unsigned app when you only need a local/dev artifact:
   - `./scripts/package_release.sh`
4. For end-user direct downloads, build the signed artifact instead:
   - `./scripts/package_signed_release.sh --team-id <TEAM_ID> --notary-profile <PROFILE>`
5. Create a GitHub release tag like `v0.1.2` with `build/SpotlightCaffeinate.zip`.
6. Update the Homebrew tap repo `TaylorFinklea/homebrew-tap`:
   - `Casks/spotlight-caffeinate.rb`
   - set the new `version`
   - set the new `sha256`

## Distribution Notes

- Homebrew distribution is via cask, not formula:
  - `brew install --cask TaylorFinklea/tap/spotlight-caffeinate`
- `scripts/package_release.sh` is still the unsigned packaging path for local/dev builds.
- Release builds intended for end users should prefer `scripts/package_signed_release.sh`.
- Unsigned artifacts may still need quarantine removal after install:
  - `xattr -dr com.apple.quarantine "/Applications/Spotlight Caffeinate.app"`
