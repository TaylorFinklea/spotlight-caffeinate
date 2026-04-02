#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Render the Homebrew formula for the prebuilt CLI release artifact.

Usage:
  ./scripts/render_homebrew_cli_formula.sh [--version <version>] [--sha256 <sha256>]

Defaults:
  --version uses MARKETING_VERSION from project.yml
  --sha256 uses build/spotlight-caffeinate-cli.tar.gz when present
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_path="$repo_root/build/spotlight-caffeinate-cli.tar.gz"
version="$(awk '/MARKETING_VERSION:/ { print $2; exit }' "$repo_root/project.yml")"
sha256=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --sha256)
      sha256="${2:-}"
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

if [[ -z "$version" ]]; then
  echo "Unable to determine version from project.yml. Pass --version explicitly." >&2
  exit 1
fi

if [[ -z "$sha256" ]]; then
  if [[ ! -f "$archive_path" ]]; then
    echo "Missing $archive_path. Build the CLI release or pass --sha256 explicitly." >&2
    exit 1
  fi
  sha256="$(shasum -a 256 "$archive_path" | awk '{ print $1 }')"
fi

cat <<EOF
class SpotlightCaffeinateCli < Formula
  desc "Terminal interface for Spotlight Caffeinate"
  homepage "https://github.com/TaylorFinklea/spotlight-caffeinate"
  url "https://github.com/TaylorFinklea/spotlight-caffeinate/releases/download/v${version}/spotlight-caffeinate-cli.tar.gz"
  sha256 "${sha256}"
  license "GPL-3.0-only"

  depends_on :macos

  def install
    bin.install "spotlight-caffeinate-cli"
    bin.install_symlink "spotlight-caffeinate-cli" => "caf"
  end

  test do
    assert_match "not running", shell_output("#{bin}/spotlight-caffeinate-cli status")
  end
end
EOF
