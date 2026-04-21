# Changelog

All notable user-facing changes to Spotlight Caffeinate are documented here. Format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project follows [Semantic Versioning](https://semver.org/).

Each release heading matches the Git tag pushed for that version.

## [Unreleased]

Nothing user-facing yet. Drafts land here and are promoted to the next version section at tag time.

## [1.0.0] — TBD

First stable release. Ships to App Store, Homebrew (cask and formula), and signed direct download on the same day.

### Added
- App Sandbox support in the menu bar app so it can be distributed through the Mac App Store.
- Bundled CLI in the app bundle at `Contents/Resources/cli/spotlight-caffeinate-cli`, with `install-cli.sh` to put it on `$PATH`.
- App Group sync (`group.io.taylorfinklea.spotlightcaffeinate`) so the signed menu bar app and the bundled CLI share presets, automations, session state, and history.
- Standalone CLI warning when a sandboxed app install is present but the standalone CLI is using its own local state.
- Binary-only CLI installer: `scripts/install_cli_release.sh` downloads the published tarball and drops `spotlight-caffeinate-cli` plus a `caf` alias into `~/.local/bin`.
- Homebrew tap auto-update workflow: `.github/workflows/update-homebrew-tap.yml` renders the cask and formula for `TaylorFinklea/homebrew-tap` from the published release assets when `HOMEBREW_TAP_PAT` is configured.
- Developer ID signing + notarization workflow (`scripts/package_signed_release.sh`, `scripts/configure_notarytool_profile.sh`).
- Mac App Store packaging workflow (`scripts/package_app_store_release.sh`) producing `build/SpotlightCaffeinateAppStore.xcarchive` for upload through Xcode Organizer or Transporter.
- Structured `os.Logger` output for automation evaluation failures (subsystem `io.taylorfinklea.spotlightcaffeinate`, category `automation`).
- Structured `os.Logger` output for the notification enable flow (category `controller`) with a warning when app activation does not land inside the 500 ms budget.

### Changed
- Notification enable flow no longer races a fixed 200 ms sleep against `NSApplication.activate(...)`. The app now waits on `NSApplication.didBecomeActiveNotification` with a 500 ms fallback, and skips the wait entirely when the activation policy is already `.regular` and the app is already active.
- CLI storage context now honours the `SPOTLIGHT_CAFFEINATE_STORAGE_ROOT` environment variable. Intended for integration tests; users should not rely on it.

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
