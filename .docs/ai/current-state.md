# Current State

## Branch

- Active branch: `main`
- Ahead of `origin/main` by the prior commits plus the bundle-ID rename slice
  landed on 2026-05-06.

## Recent Progress

### Bundle ID rename (2026-05-06)

`io.taylorfinklea.*` was always a placeholder reverse-DNS for a domain
that wasn't owned. Renamed across the source tree and docs to
`dev.finklea.spotlightcaffeinate` (CLI: `dev.finklea.spotlightcaffeinate.cli`;
App Group: `group.dev.finklea.spotlightcaffeinate`). All 78 tests pass on
the new bundle ID. The broken v1.0.0 GitHub release and tag were deleted —
nothing to migrate from since the prior 1.0.0 signed app could not launch.
A new Developer ID provisioning profile must be created against the new
bundle ID (see decisions.md and the roadmap Now block).

### M3 — Menu bar glyph polish (done 2026-04-30)

Seven sequenced commits landed the first M3 slice ("menu bar glyph
polish"). Plan source: `~/.claude/plans/wise-imagining-platypus.md`.

- `36cde36` — replace `BoltShape` path with the new bolder C3 bolt
  (rounded stroke overlay for soft joins/caps).
- `972cede` — regenerate every `AppIcon.appiconset` PNG to match the
  new bolt geometry. Adds `scripts/generate_app_icon.swift` (Core
  Graphics renderer) so future bolt changes have a reproducible
  pipeline at every required pixel size.
- `d098cc4` — add `GlyphStyle` (`boltFill` / `ring` / `text`) and
  `PulseThreshold` (`off` / `seconds30` / `minute1` / `minutes5`)
  preference enums plus Codable / default-value tests.
- `454d948` — add `RingProgressIconView` (style B) and
  `CompactBoltIconView` (style C). Rename `MenuBarBoltRenderer` →
  `MenuBarGlyphRenderer`; cache key now includes the rendering kind.
  `CaffeinateController` gains `glyphStyle` + `pulseThreshold`
  properties with one-shot legacy migration: existing users with
  `showMenuBarTime=true` get `.text`; everyone else gets `.boltFill`.
- `62fd3d3` — `ModeDotsView` (1/2/3 dots for display/system/full).
  Renderer composes glyph + dot strip in a VStack and grows the
  rendered image height when a session is running. Cache key gains a
  `mode` field.
- `54f25de` — pulse animation. `PulseThreshold` gets a
  `shouldPulse(remainingSeconds:)` predicate. `CaffeinateController`
  exposes `pulseOpacity` and `isNearExpiry`; a 200ms pulse task ticks
  an 8-step cosine breath envelope (1.0 → 0.35 → 1.0 over ~1.6 s) when
  `shouldPulse` is true. `SpotlightCaffeinateApp` applies
  `.opacity(controller.pulseOpacity)` to the menu bar glyph.
- `7c90fff` — Settings UI. Drops the "Show remaining time" toggle.
  Adds a "Menu Bar Appearance" card with a segmented Glyph style
  picker and a Near-expiry pulse picker, both bound to controller
  setters. The legacy `showMenuBarTime` instance state, setter, and
  helper are removed; `glyphStylePreference` still reads the legacy
  UserDefaults key once for migration.

## Milestone Snapshot

- **M1 Quality hardening** — done.
- **M2 1.0 release** — **shipped.** v1.0.0 tagged, signed, notarized,
  stapled, GitHub release published, Homebrew cask + formula updated
  via the auto-update workflow, and all three install paths
  (`brew install --cask`, formula, curl-tarball) verified launching
  on Apple Silicon. App Store submission still queued.
- **M3 Menu bar / UX polish** — glyph polish slice done. Remaining
  slices (global hotkey, accessibility pass, preset list
  enhancements, onboarding) still queued.
- **M4 Shortcuts / Spotlight depth** — stub.
- **M5 Automation trigger depth** — stub.
- **M6 Platform integrations** — stub.

## Known Limitations

- App Store submission has not happened yet for v1.0.0. App Privacy
  answer in `docs/app-store-metadata.md` is still a draft; the App
  Store Connect record needs to be re-created against the new
  `dev.finklea.spotlightcaffeinate` bundle ID (the placeholder
  `io.taylorfinklea.*` record never had a build uploaded).
- The new bolt geometry has not yet been validated on the App Store
  screenshots (the signed `/Applications` install was verified during
  the v1.0.0 cut).

## v1.0.0 Release Receipts

- Tag: `v1.0.0` pushed to `origin`.
- GitHub release: <https://github.com/TaylorFinklea/spotlight-caffeinate/releases/tag/v1.0.0>
- Asset SHA256:
  - `SpotlightCaffeinate.zip` —
    `97e5f76394dcd0f9088758210b5eda1fc6e9d3b1edc87546b949ae3f95db8569`
  - `spotlight-caffeinate-cli.tar.gz` —
    `607862a85557edbdba42ff589d205b95337fcbf0df66436c4889b7452fe1e166`
- Tap (`TaylorFinklea/homebrew-tap`) cask + formula updated by
  `update-homebrew-tap.yml` workflow runs (`workflow_dispatch` and
  `release` triggers, both succeeded).
- Verified install paths:
  1. `brew install --cask TaylorFinklea/tap/spotlight-caffeinate` →
     `/Applications/Spotlight Caffeinate.app` launches without amfid
     rejection (`spctl --assess`: `accepted source=Notarized
     Developer ID`).
  2. `brew install TaylorFinklea/tap/spotlight-caffeinate-cli` →
     `spotlight-caffeinate-cli` and `caf` on `$PATH`, `status` works.
  3. `curl ... | tar -xz` from the release tarball → CLI runs
     directly.

## Current Blockers

- None at the code level.
- Release-execution blockers remain user-owned (see next-steps).

## Manual QA Flagged For User

Two M1 items are still queued (unchanged from prior session):

1. **Automation logging.** Install the Debug build, corrupt the real
   App Group `automations.json`, toggle an automation enabled, and run
   `log stream --predicate 'subsystem == "dev.finklea.spotlightcaffeinate" && category == "automation"'`
   to confirm the new error line appears.
2. **Notification activation.** Delete
   `~/Library/Group Containers/group.dev.finklea.spotlightcaffeinate`,
   cold-launch the app, toggle notifications on from the menu, confirm
   the macOS auth prompt appears reliably.

New M3 manual QA items:

3. **Glyph styles render correctly in the menu bar.** Switch through
   Bolt fill / Ring / Bolt + Time in Settings. Each renders cleanly at
   the system menu bar height, including the mode-dot strip when a
   session is running.
4. **Near-expiry pulse behaves.** Start a 2-minute session with the
   default 1-minute threshold; confirm the bolt begins fading at
   ~1:00 remaining, stops on extend or stop. Repeat with each pulse
   threshold value (Off / 30s / 1m / 5m).
5. **App icon regeneration.** After installing the build into
   `/Applications`, confirm Finder, Dock, Launchpad, and About-window
   icons all show the new bolt at every preview size.

## Validation / Test Status

- `xcodebuild test` on `SpotlightCaffeinate` scheme: **78 tests in 12
  suites** green (was 68 in 10 before this session). Adds 10 new
  tests across `GlyphStyleTests`, `PulseThresholdTests`.
- `bash -n` passes for every script in `scripts/` (including the new
  `generate_app_icon.swift` Swift script).
- `scripts/release_preflight.sh` is **green** on the post-M3 cut.
- No signed build or App Store archive attempted this session.

## Notes

- The live execution queue lives in `.docs/ai/roadmap.md` under
  **Now / Next / Later**.
- M3 phase brief (`.docs/ai/phases/M3-...`) does not yet exist; plan
  for the glyph slice lives at
  `~/.claude/plans/wise-imagining-platypus.md` if a follow-up agent
  needs the design rationale.
