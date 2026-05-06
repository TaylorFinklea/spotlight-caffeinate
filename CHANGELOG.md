# Changelog

All notable user-facing changes to Spotlight Caffeinate are documented here. Format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project follows [Semantic Versioning](https://semver.org/).

Each release heading matches the Git tag pushed for that version.

## [Unreleased]

Nothing user-facing yet. Drafts land here and are promoted to the next version section at tag time.

## [1.0.3] — 2026-05-06

### Changed
- Menu bar bolt-tile now uses a much rounder corner radius (45% of the tile, up from 30%) so the squircle reads as round at the small 15pt menu bar size where the prior radius still felt blocky. The app icon corner stays at 30% — it already read as round at full icon sizes.

## [1.0.2] — 2026-05-06

### Changed
- Softer corner radius and a touch more weight on the bolt-tile outline. The squircle radius moves from 24% to 30% of the tile, and the outer stroke from 14% to 18%, so the menu bar mark feels less angular.

## [1.0.1] — 2026-05-06

### Changed
- Thicker outline around the menu bar bolt and the app icon's rounded square. The previous 8% stroke read as a hairline at menu bar size; bumped to 14% so it visually matches the bolt's body weight.

## [1.0.0] — 2026-05-05

First stable release. Ships to Homebrew (cask and formula) and signed direct download on the same day. App Store submission follows under separate cover.

### Added
- App Sandbox support in the menu bar app so it can be distributed through the Mac App Store.
- Bundled CLI in the app bundle at `Contents/Resources/cli/spotlight-caffeinate-cli`, with `install-cli.sh` to put it on `$PATH`.
- App Group sync (`group.dev.finklea.spotlightcaffeinate`) so the signed menu bar app and the bundled CLI share presets, automations, session state, and history.
- Standalone CLI warning when a sandboxed app install is present but the standalone CLI is using its own local state.
- Binary-only CLI installer: `scripts/install_cli_release.sh` downloads the published tarball and drops `spotlight-caffeinate-cli` plus a `caf` alias into `~/.local/bin`.
- Homebrew tap auto-update workflow: `.github/workflows/update-homebrew-tap.yml` renders the cask and formula for `TaylorFinklea/homebrew-tap` from the published release assets when `HOMEBREW_TAP_PAT` is configured.
- Developer ID signing + notarization workflow (`scripts/package_signed_release.sh`, `scripts/configure_notarytool_profile.sh`).
- Mac App Store packaging workflow (`scripts/package_app_store_release.sh`) producing `build/SpotlightCaffeinateAppStore.xcarchive` for upload through Xcode Organizer or Transporter.
- Structured `os.Logger` output for automation evaluation failures (subsystem `dev.finklea.spotlightcaffeinate`, category `automation`).
- Structured `os.Logger` output for the notification enable flow (category `controller`) with a warning when app activation does not land inside the 500 ms budget.
- New bolt logo: bolder geometric proportions with rounded line joins/caps, regenerated across every app-icon size.
- Selectable menu bar glyph style in Settings → Menu Bar Appearance: **Bolt** (drain fill, default), **Ring** (circular progress arc with a static bolt), or **Bolt + Time** (compact bolt next to remaining-time text).
- Mode indicator dots beneath the menu bar glyph: 1 dot = display, 2 = system, 3 = full. Visible only while a session is running.
- Configurable near-expiry pulse: a soft opacity breath when remaining time falls below the chosen threshold (Off / 30 sec / 1 min default / 5 min).

### Changed
- Notification enable flow no longer races a fixed 200 ms sleep against `NSApplication.activate(...)`. The app now waits on `NSApplication.didBecomeActiveNotification` with a 500 ms fallback, and skips the wait entirely when the activation policy is already `.regular` and the app is already active.
- CLI storage context now honours the `SPOTLIGHT_CAFFEINATE_STORAGE_ROOT` environment variable. Intended for integration tests; users should not rely on it.
- The legacy "Show remaining time in the menu bar" toggle is replaced by the new Glyph style picker; existing users with the toggle enabled migrate automatically to the **Bolt + Time** style.

### Fixed
- Assertion cleanup and startup privacy prompt no longer leak or misfire.
- CLI session persistence across invocations.
- CLI notification service crash on certain startup paths.
- Spotlight preset intent selection and option conversion.

## Prior releases

Earlier versions (`v0.1.0` through `v0.4.0`) predate this changelog. Their user-facing scope is summarised in the Git history and in `docs/app-store-metadata.md`.

<!--
Maintenance notes for Claude and collaborators:

- Every release tag must have a matching `## [X.Y.Z]` heading. `scripts/package_signed_release.sh` fails fast if the `MARKETING_VERSION` in `project.yml` is not referenced here.
- Draft user-facing changes under `## [Unreleased]` during the development cycle; promote them when cutting a release.
- Keep entries brief and user-focused. Implementation details belong in commit messages and `.docs/ai/decisions.md`.
-->
