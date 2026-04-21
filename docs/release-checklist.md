# Release Checklist

Use this checklist when shipping `Spotlight Caffeinate` to end users.

## Before Tagging

1. Pull and rebase on `main`.
2. Bump the version in `project.yml` (both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`).
3. Promote the `## [Unreleased]` section of `CHANGELOG.md` to the new version heading. `scripts/package_signed_release.sh` and `scripts/release_preflight.sh` both fail fast if there is no matching entry.
4. Run `xcodegen generate`.
5. Run `./scripts/release_preflight.sh` — this regenerates the project, builds both targets, runs the test suite, shell-lints `scripts/`, and verifies the changelog. Any manual gates it does not cover are listed at the end of its output.

## Signed Build Validation

These checks must be performed from a signed app copied into `/Applications`.

- Do not validate notifications or launch at login from `CODE_SIGNING_ALLOWED=NO` builds.
- Install the signed build into `/Applications/Spotlight Caffeinate.app`.
- Launch it once from `/Applications`.
- Confirm the menu bar icon appears and the menu opens correctly.
- Confirm presets can be started from the menu bar UI.
- Confirm Spotlight actions work for start, stop, extend, restart, and status.
- Confirm `Enable Notifications` triggers the native macOS permission prompt when the authorization state is clean.
- Confirm a short run posts the completion notification.
- Confirm `Open Spotlight Caffeinate at Login` registers successfully.
- Confirm the CLI installed from the app bundle stays in sync with the running app for start, status, extend, and stop.

## Distribution

1. Build the signed release:
   - `./scripts/package_signed_release.sh --team-id <TEAM_ID> --notary-profile <PROFILE>`
2. Optionally build the CLI release tarball for direct download:
   - `./scripts/package_cli_release.sh`
3. Confirm the exported app is notarized and stapled.
4. Confirm the exported app bundle contains:
   - `Contents/Resources/cli/spotlight-caffeinate-cli`
   - `Contents/Resources/cli/install-cli.sh`
5. Create the GitHub release with:
   - `build/SpotlightCaffeinate.zip`
   - `build/spotlight-caffeinate-cli.tar.gz`
6. Update the Homebrew tap:
   - `Casks/spotlight-caffeinate.rb`
   - `Formula/spotlight-caffeinate-cli.rb`
   - set the new `version`
   - set the cask SHA256 from `SpotlightCaffeinate.zip`
   - set the formula URL to `https://github.com/TaylorFinklea/spotlight-caffeinate/releases/download/v<TAG>/spotlight-caffeinate-cli.tar.gz`
   - set the formula SHA256 from `build/spotlight-caffeinate-cli.tar.gz`
   - formula install should `bin.install "spotlight-caffeinate-cli"` and add the `caf` symlink
   - `./scripts/render_homebrew_cli_formula.sh --version <TAG_WITHOUT_V>` prints the expected formula body
   - `./scripts/render_homebrew_cask.sh --version <TAG_WITHOUT_V>` prints the expected cask body
   - if `HOMEBREW_TAP_PAT` is configured in this repo, `.github/workflows/update-homebrew-tap.yml` can push both tap updates automatically after the GitHub release is published
7. Verify a fresh Homebrew install of the released cask.
8. Verify the bundled installer from the app:
   - `/Applications/Spotlight Caffeinate.app/Contents/Resources/cli/install-cli.sh`
   - `spotlight-caffeinate-cli status`
   - `spotlight-caffeinate-cli start 5`
   - verify the menu bar app shows the same running session
9. Verify a fresh Homebrew install of the released formula:
   - `brew tap TaylorFinklea/tap`
   - `brew install spotlight-caffeinate-cli`
   - or `brew install TaylorFinklea/tap/spotlight-caffeinate-cli`
   - `spotlight-caffeinate-cli status`
   - confirm the CLI warns that it uses independent local state when the app is also installed
