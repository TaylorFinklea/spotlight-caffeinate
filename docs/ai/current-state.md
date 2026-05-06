# Current State

## Branch

- Active branch: `main`

## Recent Progress

- Fixed native assertion-backed sessions so they time out correctly and can be stopped or archived after relaunch using persisted assertion IDs.
- Stopped probing `~/Library/Containers/dev.finklea.spotlightcaffeinate` directly during startup; legacy sandbox-path detection now only uses the current process application-support location when it is already sandboxed.
- Added regression tests covering expired assertion cleanup, cross-instance assertion stop behavior, and automation harness compatibility with the assertion-backed process controller.
- Added App Group-based shared storage resolution so the signed app and bundled CLI can sync state again.
- Added one-time migration logic for legacy app and standalone CLI data into the shared container.
- Added standalone CLI warning behavior for unsynced installs.
- Added shared AI handoff workflow docs and aligned repo instructions for both Codex and Claude.
- Enabled signed local builds against Apple team `K7CBQW6MPG` and verified the App Group entitlement resolves in the built app and bundled CLI.
- Installed a signed app into `/Applications`, ran the bundled CLI installer, and verified `start`, `status`, `extend`, and `stop` use the shared App Group container successfully.
- Updated the Mac App Store packaging script to produce the archive only and leave upload to Xcode Organizer or Transporter, which matches the current local Xcode export behavior for this app.
- Added a release-based CLI installer script so terminal-only installs can avoid local `xcodebuild`.
- Added a Homebrew formula renderer script and updated release/docs guidance so the CLI formula should consume the prebuilt release tarball instead of building from the source archive.
- Added a GitHub Actions workflow that can update the Homebrew tap from published release asset digests when `HOMEBREW_TAP_PAT` is configured.
- Updated `TaylorFinklea/homebrew-tap` `main` so `spotlight-caffeinate-cli` now installs from the prebuilt release tarball instead of invoking `xcodebuild`.

## Changed Files In Current Session

- `SpotlightCaffeinate/Services/CaffeinateService.swift`
- `SpotlightCaffeinate/Support/CaffeinateProcessController.swift`
- `SpotlightCaffeinate/Support/SpotlightCaffeinatePaths.swift`
- `SpotlightCaffeinateTests/AutomationServiceTests.swift`
- `SpotlightCaffeinateTests/CaffeinateServiceTests.swift`
- `SpotlightCaffeinateTests/SpotlightCaffeinatePathsTests.swift`
- `docs/ai/roadmap.md`
- `docs/ai/current-state.md`
- `docs/ai/next-steps.md`
- `docs/ai/decisions.md`
- `docs/ai/handoff-template.md`
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
- `.github/workflows/update-homebrew-tap.yml`
- `scripts/render_homebrew_cask.sh`

## Current Blockers

- No code blocker is currently open for signed App Group sync.
- The launch-time privacy prompt fix and post-expiry sleep behavior were validated through unit/integration coverage, but still need a signed `/Applications` runtime sanity check on the menu bar app itself.
- Installed a fresh signed archive build into `/Applications` and verified:
  - the app launches and stays running from `/Applications`
  - no visible `CoreServicesUIAgent` privacy alert window appeared after launch
  - no matching `"would like to access data from other apps"` string appeared in the recent system log sample after launch
  - the bundled CLI reinstalled from the app successfully
  - a one-minute installed-bundle session expired cleanly and `pmset -g assertions` returned to the baseline state afterward
- The remaining runtime gap is direct UI coverage of the app-native assertion path started from the menu bar or Spotlight action itself; the assertion backend is covered by tests, but this specific interactive path was not automated in this session.
- The new tap-update workflow still requires the repo secret `HOMEBREW_TAP_PAT` before release publishing can update `TaylorFinklea/homebrew-tap` automatically.
- Remaining release work is execution work: finish App Store metadata, capture screenshots, create the archive, and upload it from Organizer or Transporter.

## Open Questions

- The local signed build resolved the app ID to team `K7CBQW6MPG`, but the signing identity selected by Xcode during local development was `Apple Development: taylor.finklea@icloud.com (N8SUK4L228)`. Confirm this is the expected local-account setup before final release signing if signing behavior looks inconsistent.

## Validation / Test Status

- For the assertion-timeout and privacy-prompt pass:
  - macOS test suite passed with:
    - `xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedDataDebugTestsFix CODE_SIGNING_ALLOWED=NO test`
  - sandboxed `xcodebuild` still fails on Swift macro plugin execution; use the normal host environment for reliable validation.
  - signed archive build succeeded with:
    - `./scripts/package_signed_release.sh --team-id K7CBQW6MPG`
    - note: the archive/export script still fails at the `developer-id` export step on the current toolchain, matching the existing repo note, but the archive bundle itself was produced and used for runtime validation
  - installed-app runtime check passed for the bundled CLI path:
    - installed `build/SpotlightCaffeinate.xcarchive/Products/Applications/Spotlight Caffeinate.app` into `/Applications`
    - reinstalled the bundled CLI from `/Applications/Spotlight Caffeinate.app/Contents/Resources/cli/install-cli.sh`
    - `spotlight-caffeinate-cli start 1` produced the expected temporary `caffeinate` assertions
    - after expiry, `spotlight-caffeinate-cli status` returned idle and `pmset -g assertions` no longer showed the session-owned assertions

- For the App Group provisioning/signing pass:
  - `xcodegen generate` passed
  - signed app Debug build with `-allowProvisioningUpdates` passed
  - entitlements inspection confirmed:
    - app sandbox enabled
    - App Group `group.dev.finklea.spotlightcaffeinate`
    - calendar entitlement on the app target
  - signed `/Applications` runtime validation passed for the bundled CLI sync path:
    - `start`
    - `status`
    - `extend`
    - `stop`
  - App Group container files were created under `~/Library/Group Containers/group.dev.finklea.spotlightcaffeinate/SpotlightCaffeinate`
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
- For the Homebrew tap automation work:
  - `bash -n scripts/render_homebrew_cask.sh` passed
  - Ruby YAML parse of `.github/workflows/update-homebrew-tap.yml` passed
  - `./scripts/render_homebrew_cask.sh --version 0.4.0 --sha256 635764...` rendered the expected cask body
  - live tap update pushed to `TaylorFinklea/homebrew-tap` commit `c57b413`

## Notes

- Repo instructions now point at `docs/ai/` as the canonical handoff location. A repo-local `docs/ai/` copy was created from the existing `.docs/ai/` content so future assistants can follow the documented workflow without relying on the legacy hidden directory.
- Use `docs/ai/next-steps.md` as the immediate execution queue.
- Use `docs/ai/decisions.md` for durable decisions instead of burying them in commit history or chat.
