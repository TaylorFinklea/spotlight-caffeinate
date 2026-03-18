#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$repo_root/build"
derived_data_path="${DERIVED_DATA_PATH:-$build_root/DerivedDataCLIRelease}"
archive_path="$build_root/spotlight-caffeinate-cli.tar.gz"
binary_name="spotlight-caffeinate-cli"
alias_name="caf"
binary_path="$derived_data_path/Build/Products/Release/$binary_name"

mkdir -p "$build_root"
staging_dir="$(mktemp -d "$build_root/cli-package.XXXXXX")"

cleanup() {
  rm -rf "$staging_dir"
}
trap cleanup EXIT

rm -rf "$derived_data_path" "$archive_path"

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

cp "$binary_path" "$staging_dir/$binary_name"
chmod +x "$staging_dir/$binary_name"
ln -s "$binary_name" "$staging_dir/$alias_name"

tar -C "$staging_dir" -czf "$archive_path" "$binary_name" "$alias_name"

echo "Created $archive_path"
shasum -a 256 "$archive_path"
