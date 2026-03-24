# Mac App Store Checklist

Use this checklist when shipping `Spotlight Caffeinate` through the Mac App Store.

## Before Archiving

1. Pull and rebase on `main`.
2. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
3. Run `xcodegen generate`.
4. Verify local gates:
   - app Debug build
   - CLI Debug build
   - test target
5. Confirm the release metadata is ready:
   - app name
   - subtitle
   - description
   - keywords
   - support URL
   - marketing URL if you have one
   - privacy policy URL
   - screenshots
   - pricing decision

## App Store Connect

1. Create the app record if it does not exist yet.
2. Set the primary category to Utilities.
3. Set the app price in Pricing and Availability.
4. Fill out App Privacy.
5. Fill out content rights and age rating.
6. Add the support URL and privacy policy URL.

## Archive And Upload

1. Build the App Store archive:
   - `./scripts/package_app_store_release.sh --team-id <TEAM_ID>`
2. Open the generated archive in Xcode Organizer if you want to validate or upload from Xcode.
3. Upload the exported App Store build to App Store Connect.
4. Wait for App Store Connect processing to finish.

## Final Review

1. Attach the processed build to the app version.
2. Confirm release notes and pricing one more time.
3. Submit the version for review.
4. After approval, release manually or use automatic release.

## Notes

- The App Store build is sandboxed and uses native power assertions instead of launching `/usr/bin/caffeinate`.
- Existing direct-download users will not automatically share on-disk state with the sandboxed App Store build.
- Keep the direct-download notarized build flow separate from the App Store flow.
