# Next Steps

M1 is done. Source has been cut to 1.0.0 (`MARKETING_VERSION` 1.0.0,
`CURRENT_PROJECT_VERSION` 10, `CHANGELOG.md` 1.0.0 dated 2026-04-27)
and the previously-deferred CLI integration tests are re-enabled and
green. Everything left is user-gated.

## M1 manual QA (before cutting 1.0)

- [ ] Install a signed Debug build into `/Applications`, corrupt
      `~/Library/Group Containers/group.io.taylorfinklea.spotlightcaffeinate/SpotlightCaffeinate/automations.json`,
      toggle an automation on, then
      `log stream --predicate 'subsystem == "io.taylorfinklea.spotlightcaffeinate" && category == "automation"'`
      should show the new error line.
- [ ] Delete `~/Library/Group Containers/group.io.taylorfinklea.spotlightcaffeinate`,
      cold-launch the app, toggle notifications on, confirm the macOS
      auth prompt appears reliably and the `category == "controller"`
      warning does **not** fire on the happy path.

## M2 user-owned execution queue

1. **Pre-flight on the 1.0.0 cut:**
   - [ ] `./scripts/release_preflight.sh` — must pass clean.
2. **Signed `/Applications` release-checklist pass:**
   - [ ] Build signed + notarized via
         `./scripts/package_signed_release.sh --team-id K7CBQW6MPG --notary-profile <PROFILE>`.
   - [ ] Install the result into `/Applications` and walk through every
         bullet in `docs/release-checklist.md`.
3. **App Store Connect:**
   - [ ] Capture / refresh screenshots (main menu active, main menu
         idle, presets, automations, settings).
   - [ ] Set pricing.
   - [ ] Submit App Privacy answers ("No data collected"). Draft lives
         at `docs/app-store-metadata.md`.
   - [ ] Submit App Review notes. Draft lives at
         `docs/app-store-metadata.md`.
   - [ ] Build the archive via
         `./scripts/package_app_store_release.sh --team-id K7CBQW6MPG`.
   - [ ] Upload from Xcode Organizer or Transporter.
4. **Homebrew tap automation:**
   - [ ] Add the `HOMEBREW_TAP_PAT` repo secret (GitHub PAT with push
         rights to `TaylorFinklea/homebrew-tap`).
   - [ ] Confirm `.github/workflows/update-homebrew-tap.yml` runs on
         release publish.
5. **GitHub release:**
   - [ ] Rebuild CLI tarball: `./scripts/package_cli_release.sh` (the
         dry-run tarball at `build/spotlight-caffeinate-cli.tar.gz` was
         produced locally on 2026-04-27, but should be regenerated on
         the release branch immediately before tagging).
   - [ ] Tag `v1.0.0` and push.
   - [ ] Attach `build/SpotlightCaffeinate.zip` and
         `build/spotlight-caffeinate-cli.tar.gz` to the release.
6. **Post-publish verification:**
   - [ ] `brew install --cask TaylorFinklea/tap/spotlight-caffeinate`
         installs and launches the 1.0 app.
   - [ ] `brew install TaylorFinklea/tap/spotlight-caffeinate-cli`
         installs the 1.0 CLI.
   - [ ] `curl -fsSL https://github.com/TaylorFinklea/spotlight-caffeinate/releases/latest/download/spotlight-caffeinate-cli.tar.gz | tar -xz -C $HOME/.local/bin`
         works.
   - [ ] App Store listing is live.

## Ongoing

- [ ] Keep `.docs/ai/current-state.md`, `.docs/ai/next-steps.md`, and
      `.docs/ai/decisions.md` current at the end of each session.
- [ ] When a Haiku/Sonnet backlog item is picked up, follow the claim
      protocol: flip `- [ ]` → `- [~]` and commit, then `- [x]` on
      completion.
