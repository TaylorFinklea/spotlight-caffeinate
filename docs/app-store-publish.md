# Spotlight Caffeinate Mac App Store Publish Guide

Use this document as the single source of truth for publishing `Spotlight Caffeinate` to the Mac App Store.

## Current State

The app is already prepared for Mac App Store distribution in the key areas that required code changes:

- the app is sandboxed
- the app uses native IOKit power assertions instead of launching `/usr/bin/caffeinate`
- the app declares the Utilities category
- there is an App Store archive/export script
- there is a metadata draft and App Review notes draft

What still remains is the release execution work in App Store Connect and the final signed upload.

## App Basics

- App name: `Spotlight Caffeinate`
- Bundle ID: `io.taylorfinklea.spotlightcaffeinate`
- Platform: macOS
- Category: Utilities
- App model: menu-bar-only app using `LSUIElement`
- Pricing model: paid upfront is supported through App Store Connect pricing; no StoreKit code is required for a one-time paid download

## Important Caveats

1. Existing direct-download users will not automatically share presets, history, or automation state with the sandboxed App Store build.
2. The App Store build and the direct-download notarized build are separate distribution paths. Keep them separate operationally.
3. Launch at login should be validated on a real App Store signed build, not just an unsigned or locally signed debug build.
4. If you later add analytics, crash reporting, cloud sync, accounts, or any hosted backend, you must revisit the App Privacy answers before submission.

## One-Time Requirements

Before your first App Store release, make sure these are done:

1. Your Apple Developer Program membership is active.
2. App Store Connect agreements, banking, and tax information are complete.
3. The app record exists in App Store Connect for `io.taylorfinklea.spotlightcaffeinate`.
4. You have a real Support URL.
5. You have a real Privacy Policy URL.
6. You have macOS screenshots ready.

## Every Release: Local Preparation

Follow this sequence for every App Store release.

### 1. Sync The Repo

```bash
git pull --rebase origin main
```

### 2. Bump Version And Build

Update these values in `project.yml`:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`

Example:

```yaml
settings:
  base:
    MARKETING_VERSION: 0.5.0
    CURRENT_PROJECT_VERSION: 5
```

### 3. Regenerate The Xcode Project

```bash
xcodegen generate
```

### 4. Run Local Validation Gates

```bash
xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinate -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinateCLI -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

xcodebuild -project SpotlightCaffeinate.xcodeproj -scheme SpotlightCaffeinate -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

## App Store Metadata Package

Prepare all of the following before submission.

### Required Listing Fields

- Name
- Subtitle
- Promotional Text
- Description
- Keywords
- Primary Category
- Support URL
- Privacy Policy URL
- Screenshots
- Pricing

### Suggested Metadata Copy

#### Name

Spotlight Caffeinate

#### Subtitle

Keep your Mac awake fast

#### Promotional Text

Start a keep-awake session from the menu bar or Spotlight in seconds, with presets, recent-session restart, and optional automations.

#### Description

Spotlight Caffeinate is a focused menu bar utility for keeping your Mac awake without opening Terminal.

Start a session for a custom duration, launch a saved preset from the menu bar, or restart your most recent session with one click. Spotlight Caffeinate is built for quick access: the menu bar shows the current countdown, and Spotlight actions let you start, stop, extend, restart, or check status from anywhere.

Features:

- Start keep-awake sessions from the menu bar
- Launch from Spotlight with built-in app actions
- Save and pin presets for common durations
- Extend or stop the current session instantly
- Restart your most recent completed session
- Check current status from Spotlight
- Choose display, system, or full keep-awake modes
- Optional completion notifications
- Optional launch at login
- Optional calendar, schedule, and power-state automations

Spotlight Caffeinate is designed to do one job well: keep your Mac awake when you need it, with as little friction as possible.

#### Keywords

caffeinate,menu bar,sleep,awake,focus,productivity,spotlight,automation,utility,mac

#### Category

Utilities

### URL Guidance

- Support URL: use your product support page or GitHub support page
- Marketing URL: optional; use your product homepage if you have one
- Privacy Policy URL: required for submission

## Screenshot Plan

Recommended screenshot set:

1. Main menu with an active session running
2. Main menu showing pinned presets and custom start
3. Presets management window
4. Automations management window
5. Settings window showing notifications and launch-at-login options

Notes:

- Use a clean macOS desktop background
- Make sure the menu bar icon is visible in relevant screenshots
- Keep the screenshots tightly focused on the actual feature being shown

## App Privacy

If the app behavior stays as it is today, the likely App Privacy answer is:

- No, this app does not collect data from the user

Reasoning:

- presets, history, and automation rules are stored locally on the Mac
- notifications are local notifications only
- calendar access is used only on-device for optional calendar-triggered automations
- there are no accounts, ads, analytics, or hosted APIs in the current app

Before submitting, verify that this is still true in the exact build you are shipping.

## App Review Notes

Paste something close to this into the App Review information field:

> Spotlight Caffeinate is a menu bar-only macOS utility. After launch, it appears in the macOS menu bar instead of the Dock because the app uses `LSUIElement`.
>
> How to test:
>
> 1. Launch the app.
> 2. Click the bolt icon in the menu bar to open the main interface.
> 3. Start a session from Quick Start or Custom Start.
> 4. Optional: use Settings to enable notifications or launch at login.
> 5. Optional: use Automations to test calendar or schedule-based rules.
>
> Permission notes:
>
> - Calendar access is optional and is only used for calendar-triggered automations.
> - Notification permission is optional and is only used for local completion alerts.
> - The app does not require an account or external service.

## App Store Connect Setup

Do this in App Store Connect before you submit the build.

1. Create the app record if it does not exist yet.
2. Confirm the bundle ID is `io.taylorfinklea.spotlightcaffeinate`.
3. Set the primary category to Utilities.
4. Fill in the listing metadata.
5. Add the Support URL.
6. Add the Privacy Policy URL.
7. Complete App Privacy.
8. Complete age rating and content rights.
9. Set Pricing and Availability.

## Build The App Store Archive

Use the repo script:

```bash
./scripts/package_app_store_release.sh --team-id <YOUR_TEAM_ID>
```

Useful preview mode:

```bash
./scripts/package_app_store_release.sh --team-id <YOUR_TEAM_ID> --dry-run
```

What the script does:

1. creates a Release archive for macOS
2. exports an App Store distribution build
3. writes the exported files to `build/app-store-export`

If the script fails, check:

- your Apple Developer account access
- automatic signing configuration
- that the correct team ID is being used
- that the app record and signing assets are available to Xcode

## Upload The Build

After archiving/exporting:

1. Open Xcode Organizer and locate the archive, or use Transporter.
2. Upload the App Store build to App Store Connect.
3. Wait for App Store Connect processing to finish.
4. Confirm the processed build appears under the app version you are preparing.

## Final Submission Sequence

Once the build has processed:

1. Attach the processed build to the version in App Store Connect.
2. Recheck version number, pricing, screenshots, and URLs.
3. Paste the App Review notes.
4. Submit the app for review.
5. After approval, release manually or choose automatic release.

## Recommended Manual Validation Before Upload

Do at least one pass on a signed build copied into `/Applications`.

Validate:

1. the menu bar icon appears after launch
2. the menu opens and the main controls work
3. starting a session works
4. extending and stopping a session work
5. Spotlight actions work for start, stop, extend, restart last session, and status
6. notifications can be enabled and a completion alert is shown
7. launch at login can be enabled
8. optional calendar automation permission flow works if you are shipping that feature

## Operational Notes

- Keep the Mac App Store path separate from the direct-download notarized release path.
- Do not assume the App Store build will read old direct-download state.
- If you ever add telemetry, sync, crash reporting, or account features, update the App Privacy answers and App Review notes before submission.

## Related Files In This Repo

- App Store archive/export script: `scripts/package_app_store_release.sh`
- App Store checklist: `docs/app-store-release-checklist.md`
- App Store metadata draft: `docs/app-store-metadata.md`
- Project settings: `project.yml`

## Official Apple References

- App Sandbox: <https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox/>
- Add a new app: <https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app>
- Upload builds: <https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds>
- Set a price: <https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price>
- Submit an app: <https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app>
