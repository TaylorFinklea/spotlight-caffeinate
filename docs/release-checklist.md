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
- Confirm `Enable Notifications` triggers the native macOS permission prompt when the authorization state is clean.
- Confirm a short run posts the completion notification.
- Confirm `Open Spotlight Caffeinate at Login` registers successfully.

## Distribution

1. Build the signed release:
   - `./scripts/package_signed_release.sh --team-id <TEAM_ID> --notary-profile <PROFILE>`
2. Confirm the exported app is notarized and stapled.
3. Create the GitHub release with `build/SpotlightCaffeinate.zip`.
4. Update the Homebrew tap cask version and `sha256`.
5. Verify a fresh Homebrew install of the released cask.
