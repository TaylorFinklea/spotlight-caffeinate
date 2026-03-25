# Release Checklist

Use this checklist when shipping `Spotlight Caffeinate` to end users.

## Before Tagging

1. Pull and rebase on `main`.
2. Bump the version in `project.yml`.
3. Run `xcodegen generate`.
4. Verify local development gates:
   - app Debug build
   - CLI Debug build
   - test target

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

## Distribution

1. Build the signed release:
   - `./scripts/package_signed_release.sh --team-id <TEAM_ID> --notary-profile <PROFILE>`
2. Optionally build the CLI release tarball for direct download:
   - `./scripts/package_cli_release.sh`
3. Confirm the exported app is notarized and stapled.
4. Create the GitHub release with:
   - `build/SpotlightCaffeinate.zip`
   - optionally `build/spotlight-caffeinate-cli.tar.gz`
5. Update the Homebrew tap:
   - `Casks/spotlight-caffeinate.rb`
   - `Formula/spotlight-caffeinate-cli.rb`
   - set the new `version`
   - set the cask SHA256 from `SpotlightCaffeinate.zip`
   - set the formula SHA256 from `https://github.com/TaylorFinklea/spotlight-caffeinate/archive/refs/tags/v<TAG>.tar.gz`
6. Verify a fresh Homebrew install of the released cask.
7. Verify a fresh Homebrew install of the released formula:
   - `brew tap TaylorFinklea/tap`
   - `brew install spotlight-caffeinate-cli`
   - or `brew install TaylorFinklea/tap/spotlight-caffeinate-cli`
   - `spotlight-caffeinate-cli status`
