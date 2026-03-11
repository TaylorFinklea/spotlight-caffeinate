# Developer ID and Notarization

`Spotlight Caffeinate` ships outside the Mac App Store, so the direct-download build should use a Developer ID signature and Apple notarization.

## Prerequisites

1. Install a `Developer ID Application` certificate in your login keychain.
2. Sign in to Xcode with the Apple Developer account that owns the app.
3. Know the Apple Developer team ID you want to use for export.

You can verify the signing identity with:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

## One-Time Notary Setup

Store a reusable `notarytool` keychain profile:

```bash
./scripts/configure_notarytool_profile.sh spotlight-caffeinate-notary --team-id YOURTEAMID
```

`notarytool` will prompt for the Apple ID and app-specific password if they are not passed explicitly.

## Signed Release

Build a Developer ID signed zip without notarization:

```bash
./scripts/package_signed_release.sh --team-id YOURTEAMID
```

This produces:

- `build/export/Spotlight Caffeinate.app`
- `build/SpotlightCaffeinate.zip`

## Signed and Notarized Release

Build, submit for notarization, staple the ticket, then re-zip the stapled app:

```bash
./scripts/package_signed_release.sh \
  --team-id YOURTEAMID \
  --notary-profile spotlight-caffeinate-notary
```

The script validates the exported code signature before submission. When notarization succeeds it staples the app bundle and then recreates `build/SpotlightCaffeinate.zip` from the stapled app.

## Dry Run

If you want to verify the commands before using your signing credentials:

```bash
./scripts/package_signed_release.sh --team-id YOURTEAMID --dry-run
```

## Notes

- `scripts/package_release.sh` remains the unsigned packaging path used for local/dev builds.
- `Spotlight Caffeinate` is not sandboxed today, so this Developer ID path is for direct distribution only, not the Mac App Store.
