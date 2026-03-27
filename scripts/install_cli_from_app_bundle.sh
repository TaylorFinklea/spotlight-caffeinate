#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
destination_dir="${1:-$HOME/.local/bin}"
binary_name="spotlight-caffeinate-cli"
alias_name="caf"
binary_path="$script_dir/$binary_name"

if [[ ! -x "$binary_path" ]]; then
  echo "Bundled CLI not found at $binary_path" >&2
  exit 1
fi

mkdir -p "$destination_dir"
cp "$binary_path" "$destination_dir/$binary_name"
chmod +x "$destination_dir/$binary_name"
ln -sf "$binary_name" "$destination_dir/$alias_name"

echo "Installed bundled $binary_name to $destination_dir/$binary_name"
echo "Installed alias $alias_name to $destination_dir/$alias_name"

