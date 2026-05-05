# Current State

## Branch

- Active branch: `main`
- Ahead of `origin/main` by 22 commits (15 from prior 1.0.0 prep + 7 from this M3 glyph polish slice).

## Recent Progress

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
- **M2 1.0 release** — version cut and integration tests re-enabled;
  signing, App Store, Homebrew secret, and tag/push remain user-gated.
- **M3 Menu bar / UX polish** — glyph polish slice done. Remaining
  slices (global hotkey, accessibility pass, preset list
  enhancements, onboarding) still queued.
- **M4 Shortcuts / Spotlight depth** — stub.
- **M5 Automation trigger depth** — stub.
- **M6 Platform integrations** — stub.

## Known Limitations

- App Privacy answer in `docs/app-store-metadata.md` is still a draft;
  needs to be submitted through App Store Connect when the App Store
  upload happens.
- The new bolt geometry has not yet been validated on a signed
  `/Applications` install or in App Store screenshots.

## Changed Files In Current Session

- `SpotlightCaffeinate/App/BoltIconView.swift` (new bolt + ring +
  compact-bolt + composed renderer + mode dots)
- `SpotlightCaffeinate/App/CaffeinateController.swift` (glyphStyle,
  pulseThreshold, pulseOpacity, isNearExpiry, pulse task)
- `SpotlightCaffeinate/App/SpotlightCaffeinateApp.swift` (use
  `MenuBarGlyphView`; apply `.opacity(controller.pulseOpacity)`)
- `SpotlightCaffeinate/App/SettingsView.swift` (Menu Bar Appearance
  card)
- `SpotlightCaffeinate/Models/GlyphStyle.swift` (new)
- `SpotlightCaffeinate/Models/PulseThreshold.swift` (new)
- `SpotlightCaffeinateTests/GlyphStyleTests.swift` (new)
- `SpotlightCaffeinateTests/PulseThresholdTests.swift` (new)
- `SpotlightCaffeinate/Assets.xcassets/AppIcon.appiconset/*.png`
  (10 PNGs regenerated)
- `scripts/generate_app_icon.swift` (new)
- `SpotlightCaffeinate.xcodeproj/project.pbxproj` (regenerated)
- `.docs/ai/roadmap.md` (M3 glyph slice marked done)

## Current Blockers

- None at the code level.
- Release-execution blockers remain user-owned (see next-steps).

## Manual QA Flagged For User

Two M1 items are still queued (unchanged from prior session):

1. **Automation logging.** Install the Debug build, corrupt the real
   App Group `automations.json`, toggle an automation enabled, and run
   `log stream --predicate 'subsystem == "io.taylorfinklea.spotlightcaffeinate" && category == "automation"'`
   to confirm the new error line appears.
2. **Notification activation.** Delete
   `~/Library/Group Containers/group.io.taylorfinklea.spotlightcaffeinate`,
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
