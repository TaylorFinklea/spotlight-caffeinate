# Current State

## Branch

- Active branch: `main`

## Recent Progress

- Added App Group-based shared storage resolution so the signed app and bundled CLI can sync state again.
- Added one-time migration logic for legacy app and standalone CLI data into the shared container.
- Added standalone CLI warning behavior for unsynced installs.
- Added shared AI handoff workflow docs and aligned repo instructions for both Codex and Claude.
- Enabled signed local builds against Apple team `K7CBQW6MPG` and verified the App Group entitlement resolves in the built app and bundled CLI.
- Installed a signed app into `/Applications`, ran the bundled CLI installer, and verified `start`, `status`, `extend`, and `stop` use the shared App Group container successfully.
- Updated the Mac App Store packaging script to produce the archive only and leave upload to Xcode Organizer or Transporter, which matches the current local Xcode export behavior for this app.
- Added a release-based CLI installer script so terminal-only installs can avoid local `xcodebuild`.
- Added a Homebrew formula renderer script and updated release/docs guidance so the CLI formula should consume the prebuilt release tarball instead of building from the source archive.

## Changed Files In Current Session

- `project.yml`
- `SpotlightCaffeinate.xcodeproj/project.pbxproj`
- `scripts/package_app_store_release.sh`
- `docs/developer-id-notarization.md`
- `docs/app-store-publish.md`
- `docs/ai/current-state.md`
- `docs/ai/next-steps.md`
- `docs/ai/decisions.md`
- `README.md`
- `docs/release-checklist.md`
- `AGENTS.md`
- `scripts/install_cli_release.sh`
- `scripts/render_homebrew_cli_formula.sh`

## Current Blockers

- No code blocker is currently open for signed App Group sync.
- The external Homebrew tap formula still needs to be updated to the new binary-release install path; until that lands, some `brew install spotlight-caffeinate-cli` flows will still invoke `xcodebuild`.
- Remaining release work is execution work: finish App Store metadata, capture screenshots, create the archive, and upload it from Organizer or Transporter.

## Open Questions

- The local signed build resolved the app ID to team `K7CBQW6MPG`, but the signing identity selected by Xcode during local development was `Apple Development: taylor.finklea@icloud.com (N8SUK4L228)`. Confirm this is the expected local-account setup before final release signing if signing behavior looks inconsistent.

## Validation / Test Status

- For the App Group provisioning/signing pass:
  - `xcodegen generate` passed
  - signed app Debug build with `-allowProvisioningUpdates` passed
  - entitlements inspection confirmed:
    - app sandbox enabled
    - App Group `group.io.taylorfinklea.spotlightcaffeinate`
    - calendar entitlement on the app target
  - signed `/Applications` runtime validation passed for the bundled CLI sync path:
    - `start`
    - `status`
    - `extend`
    - `stop`
  - App Group container files were created under `~/Library/Group Containers/group.io.taylorfinklea.spotlightcaffeinate/SpotlightCaffeinate`
- For the App Store packaging flow:
  - `./scripts/package_app_store_release.sh --team-id K7CBQW6MPG` passed
  - archive created at `build/SpotlightCaffeinateAppStore.xcarchive`
  - local `xcodebuild -exportArchive` did not offer a usable Mac App Store export method for this archive on the current toolchain
  - repo script now stops after archive creation and points the release flow to Xcode Organizer or Transporter for upload
- Final validation reruns after the packaging-script changes:
  - app Debug build with `CODE_SIGNING_ALLOWED=NO` passed
  - CLI Debug build with `CODE_SIGNING_ALLOWED=NO` passed
  - app test suite with `CODE_SIGNING_ALLOWED=NO` passed
- For the CLI binary-distribution tooling:
  - `bash -n scripts/install_cli_release.sh scripts/render_homebrew_cli_formula.sh` passed
  - `./scripts/install_cli_release.sh --help` passed
  - `./scripts/render_homebrew_cli_formula.sh --version 0.4.0 --sha256 <dummy>` rendered the expected binary-based formula body

## Notes

- Use `docs/ai/next-steps.md` as the immediate execution queue.
- Use `docs/ai/decisions.md` for durable decisions instead of burying them in commit history or chat.
