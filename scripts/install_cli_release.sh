#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Install the prebuilt Spotlight Caffeinate CLI from GitHub Releases.

Usage:
  ./scripts/install_cli_release.sh [--tag <tag-or-version>] [destination_dir]

Examples:
  ./scripts/install_cli_release.sh
  ./scripts/install_cli_release.sh --tag v0.4.0
  ./scripts/install_cli_release.sh ~/.local/bin

Defaults:
  --tag defaults to latest
  destination_dir defaults to ~/.local/bin
EOF
}

binary_name="spotlight-caffeinate-cli"
alias_name="caf"
tag="latest"
destination_dir="$HOME/.local/bin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      tag="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$destination_dir" != "$HOME/.local/bin" ]]; then
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 1
      fi
      destination_dir="$1"
      shift
      ;;
  esac
done

normalized_tag="$tag"
if [[ "$normalized_tag" != "latest" && "$normalized_tag" != v* ]]; then
  normalized_tag="v$normalized_tag"
fi

if [[ "$normalized_tag" == "latest" ]]; then
  archive_url="https://github.com/TaylorFinklea/spotlight-caffeinate/releases/latest/download/${binary_name}.tar.gz"
else
  archive_url="https://github.com/TaylorFinklea/spotlight-caffeinate/releases/download/${normalized_tag}/${binary_name}.tar.gz"
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

archive_path="$tmp_dir/${binary_name}.tar.gz"
curl --fail --location --silent --show-error "$archive_url" --output "$archive_path"
tar -xzf "$archive_path" -C "$tmp_dir"

mkdir -p "$destination_dir"
install -m 755 "$tmp_dir/$binary_name" "$destination_dir/$binary_name"
ln -sf "$binary_name" "$destination_dir/$alias_name"

echo "Installed $binary_name to $destination_dir/$binary_name"
echo "Installed alias $alias_name to $destination_dir/$alias_name"
echo "Source archive: $archive_url"
