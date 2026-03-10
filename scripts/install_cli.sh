#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data_path="${DERIVED_DATA_PATH:-$repo_root/build/DerivedData}"
destination_dir="${1:-$HOME/.local/bin}"
binary_name="spotlight-caffeinate-cli"
binary_path="$derived_data_path/Build/Products/Release/$binary_name"

cd "$repo_root"

xcodegen generate

xcodebuild \
  -project "$repo_root/SpotlightCaffeinate.xcodeproj" \
  -scheme SpotlightCaffeinateCLI \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$destination_dir"
cp "$binary_path" "$destination_dir/$binary_name"
chmod +x "$destination_dir/$binary_name"

echo "Installed $binary_name to $destination_dir/$binary_name"
