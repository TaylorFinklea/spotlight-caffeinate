#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Archive and export a Mac App Store build for Spotlight Caffeinate.

Usage:
  ./scripts/package_app_store_release.sh --team-id <TEAM_ID> [--dry-run]

Options:
  --team-id <TEAM_ID>  Apple Developer team ID to use for signing.
  --dry-run            Print the commands that would run and exit.
  -h, --help           Show this help text.

Environment:
  DEVELOPMENT_TEAM     Fallback for --team-id.
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
derived_data_path="${DERIVED_DATA_PATH:-$build_root/DerivedDataAppStore}"
archive_path="$build_root/SpotlightCaffeinateAppStore.xcarchive"
export_path="$build_root/app-store-export"
team_id="${DEVELOPMENT_TEAM:-}"
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      team_id="${2:-}"
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

mkdir -p "$build_root"
export_options_plist="$(mktemp "$build_root/app-store-export-options.XXXXXX")"
cleanup() {
  rm -f "$export_options_plist"
}
trap cleanup EXIT

cat >"$export_options_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>app-store</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${team_id}</string>
</dict>
</plist>
EOF

archive_cmd=(
  xcodebuild
  -project "$repo_root/SpotlightCaffeinate.xcodeproj"
  -scheme SpotlightCaffeinate
  -configuration Release
  -destination "generic/platform=macOS"
  -derivedDataPath "$derived_data_path"
  -archivePath "$archive_path"
  -allowProvisioningUpdates
  "DEVELOPMENT_TEAM=$team_id"
  archive
)

export_cmd=(
  xcodebuild
  -exportArchive
  -archivePath "$archive_path"
  -exportPath "$export_path"
  -exportOptionsPlist "$export_options_plist"
  -allowProvisioningUpdates
)

if [[ $dry_run -eq 1 ]]; then
  print_command "Archive command:" "${archive_cmd[@]}"
  print_command "Export command:" "${export_cmd[@]}"
  exit 0
fi

rm -rf "$derived_data_path" "$archive_path" "$export_path"

"${archive_cmd[@]}"
"${export_cmd[@]}"

echo "Created App Store export at $export_path"
find "$export_path" -maxdepth 2 -type f | sort
