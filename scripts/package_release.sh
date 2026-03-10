#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data_path="${DERIVED_DATA_PATH:-$repo_root/build/DerivedData}"
archive_path="$repo_root/build/SpotlightCaffeinate.zip"
app_path="$derived_data_path/Build/Products/Release/Spotlight Caffeinate.app"

rm -rf "$derived_data_path" "$archive_path"

xcodebuild \
  -project "$repo_root/SpotlightCaffeinate.xcodeproj" \
  -scheme SpotlightCaffeinate \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto -c -k --keepParent "$app_path" "$archive_path"

echo "Created $archive_path"
shasum -a 256 "$archive_path"
