#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Build a Developer ID signed macOS release and optionally notarize it.

This script archives the app, then manually codesigns the bundled CLI
and the app wrapper with "Developer ID Application: ... (TEAM_ID)",
embedding the supplied Developer ID provisioning profile so macOS will
permit launching the App Sandbox + App Group entitled bundle.

It does NOT use `xcodebuild -exportArchive`; that path is broken on the
current Xcode toolchain when the developer's Apple ID is on a personal
team that differs from the one declared in the entitlements (see
.docs/ai/decisions.md, 2026-05-05 entry).

Usage:
  ./scripts/package_signed_release.sh \
    --team-id <TEAM_ID> \
    --provision-profile <PATH> \
    [--notary-profile <PROFILE>] \
    [--dry-run]

Options:
  --team-id <TEAM_ID>             Apple Developer team ID used for codesign.
  --provision-profile <PATH>      Path to the Developer ID .provisionprofile
                                  authorising the bundle ID + App Group.
                                  Required: macOS rejects launches without
                                  it for App Sandbox + App Group bundles.
  --notary-profile <PROFILE>      Keychain profile name previously stored
                                  with `xcrun notarytool store-credentials`.
                                  When omitted, the script signs and zips
                                  but does not submit for notarization.
  --dry-run                       Print the commands that would run.
  -h, --help                      Show this help text.

Environment:
  DEVELOPMENT_TEAM                Fallback for --team-id.
  PROVISION_PROFILE_PATH          Fallback for --provision-profile.
EOF
}

print_command() {
  local label="$1"
  shift

  printf '%s\n  ' "$label"
  printf '%q ' "$@"
  printf '\n'
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$repo_root/build"
derived_data_path="${DERIVED_DATA_PATH:-$build_root/DerivedDataSigned}"
archive_path="$build_root/SpotlightCaffeinate.xcarchive"
export_path="$build_root/Export"
zip_path="$build_root/SpotlightCaffeinate.zip"
app_path="$export_path/Spotlight Caffeinate.app"
team_id="${DEVELOPMENT_TEAM:-}"
provision_profile_path="${PROVISION_PROFILE_PATH:-}"
notary_profile=""
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      team_id="${2:-}"
      shift 2
      ;;
    --provision-profile)
      provision_profile_path="${2:-}"
      shift 2
      ;;
    --notary-profile)
      notary_profile="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$team_id" ]]; then
  echo "Missing Apple Developer team ID. Pass --team-id or set DEVELOPMENT_TEAM." >&2
  exit 1
fi

if [[ -z "$provision_profile_path" ]]; then
  echo "Missing Developer ID provisioning profile. Pass --provision-profile or set PROVISION_PROFILE_PATH." >&2
  exit 1
fi

if [[ ! -f "$provision_profile_path" ]]; then
  echo "Provisioning profile not found at $provision_profile_path" >&2
  exit 1
fi

marketing_version=$(awk '/^[[:space:]]*MARKETING_VERSION:/ {print $2; exit}' "$repo_root/project.yml")
if [[ -z "$marketing_version" ]]; then
  echo "Could not read MARKETING_VERSION from project.yml." >&2
  exit 1
fi

if [[ ! -f "$repo_root/CHANGELOG.md" ]]; then
  echo "CHANGELOG.md is missing. Add a release entry before building a signed release." >&2
  exit 1
fi

if ! grep -qE "^## \[${marketing_version//./\\.}\]" "$repo_root/CHANGELOG.md"; then
  echo "CHANGELOG.md has no \"## [$marketing_version]\" section. Promote ## [Unreleased] before tagging." >&2
  exit 1
fi

mkdir -p "$build_root"

archive_cmd=(
  xcodebuild
  -project "$repo_root/SpotlightCaffeinate.xcodeproj"
  -scheme SpotlightCaffeinate
  -configuration Release
  -destination "platform=macOS"
  -derivedDataPath "$derived_data_path"
  -archivePath "$archive_path"
  -allowProvisioningUpdates
  "DEVELOPMENT_TEAM=$team_id"
  archive
)

cli_path="$app_path/Contents/Resources/cli/spotlight-caffeinate-cli"
cli_entitlements="$repo_root/SpotlightCaffeinateCLI/SpotlightCaffeinateCLI.entitlements"
app_entitlements="$repo_root/SpotlightCaffeinate/SpotlightCaffeinate.entitlements"

# Spell out the full identity name so codesign does not pick the
# Apple Distribution cert for the same team (which happens with the
# bare team-id form when both certs are in the keychain).
codesign_identity=$(security find-identity -v -p codesigning \
  | awk -v team="$team_id" '
    /Developer ID Application/ && $0 ~ ("\\(" team "\\)") {
      if (match($0, /"[^"]+"/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  ')

if [[ -z "$codesign_identity" ]]; then
  cat >&2 <<EOF
No "Developer ID Application" signing identity for team ${team_id} is in the keychain.
Create or download that certificate first, then rerun this script.
EOF
  exit 1
fi

codesign_cli_cmd=(
  codesign --force --options runtime --timestamp
  --sign "$codesign_identity"
  --entitlements "$cli_entitlements"
  "$cli_path"
)

codesign_app_cmd=(
  codesign --force --options runtime --timestamp
  --sign "$codesign_identity"
  --entitlements "$app_entitlements"
  "$app_path"
)

if [[ $dry_run -eq 1 ]]; then
  print_command "Archive command:" "${archive_cmd[@]}"
  printf 'Then copy archive .app to %q and embed %q at Contents/embedded.provisionprofile\n' "$app_path" "$provision_profile_path"
  print_command "Codesign CLI:" "${codesign_cli_cmd[@]}"
  print_command "Codesign app wrapper:" "${codesign_app_cmd[@]}"
  if [[ -n "$notary_profile" ]]; then
    printf 'Notary profile: %s\n' "$notary_profile"
  fi
  exit 0
fi

rm -rf "$derived_data_path" "$archive_path" "$export_path" "$zip_path"

"${archive_cmd[@]}"

# Bypass `xcodebuild -exportArchive`: copy the archived .app directly,
# embed the Developer ID provisioning profile, and re-codesign manually.
mkdir -p "$export_path"
cp -R "$archive_path/Products/Applications/Spotlight Caffeinate.app" "$export_path/"
cp "$provision_profile_path" "$app_path/Contents/embedded.provisionprofile"

# Sign the bundled CLI first so the wrapper signature seals over the
# updated CLI signature and the embedded profile.
"${codesign_cli_cmd[@]}"
"${codesign_app_cmd[@]}"

codesign --verify --deep --strict --verbose=2 "$app_path"
spctl --assess --type execute --verbose=2 "$app_path" || \
  echo "Note: spctl assessment will fail until notarization completes." >&2

ditto -c -k --keepParent "$app_path" "$zip_path"

if [[ -n "$notary_profile" ]]; then
  xcrun notarytool submit "$zip_path" --keychain-profile "$notary_profile" --wait
  xcrun stapler staple "$app_path"
  xcrun stapler validate "$app_path"
  spctl --assess --type execute --verbose=2 "$app_path"
  rm -f "$zip_path"
  ditto -c -k --keepParent "$app_path" "$zip_path"
fi

echo "Created $zip_path"
shasum -a 256 "$zip_path"
