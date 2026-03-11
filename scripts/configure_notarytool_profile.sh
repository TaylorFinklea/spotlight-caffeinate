#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Store Apple notarization credentials in the keychain for later reuse.

Usage:
  ./scripts/configure_notarytool_profile.sh <profile-name> --team-id <TEAM_ID>

Examples:
  ./scripts/configure_notarytool_profile.sh spotlight-caffeinate-notary --team-id ABCDE12345

The script prompts for any missing Apple ID or app-specific password values.
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

profile_name="$1"
shift

team_id=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      team_id="${2:-}"
      shift 2
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
  echo "Missing Apple Developer team ID. Pass --team-id." >&2
  exit 1
fi

xcrun notarytool store-credentials "$profile_name" --team-id "$team_id" --sync
