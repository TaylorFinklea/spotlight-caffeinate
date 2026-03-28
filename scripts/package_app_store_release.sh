#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Archive a Mac App Store build for Spotlight Caffeinate.

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

if [[ $dry_run -eq 1 ]]; then
  print_command "Archive command:" "${archive_cmd[@]}"
  exit 0
fi

rm -rf "$derived_data_path" "$archive_path"

"${archive_cmd[@]}"

echo "Created App Store archive at $archive_path"
echo "Next step: upload the archive with Xcode Organizer or Transporter."
