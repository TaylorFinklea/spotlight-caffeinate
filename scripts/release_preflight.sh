#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Run the mechanical release gates before tagging a new Spotlight Caffeinate version.

What it does:
  1. Refuses to continue if the working tree is dirty (override with --allow-dirty).
  2. Regenerates the Xcode project via xcodegen.
  3. Builds the app target (Debug, CODE_SIGNING_ALLOWED=NO).
  4. Builds the CLI target (Debug, CODE_SIGNING_ALLOWED=NO).
  5. Runs the full test suite.
  6. Shell-lints every script in scripts/.
  7. Verifies CHANGELOG.md has an entry for the current MARKETING_VERSION in project.yml.
  8. Prints a reminder of the manual checks still owned by the human (signed /Applications
     validation, App Store upload, Homebrew tap verification).

What it does NOT do:
  - Build a signed or notarized archive. Use scripts/package_signed_release.sh for that.
  - Upload to App Store Connect. Use Xcode Organizer or Transporter.
  - Publish a GitHub release.

Usage:
  ./scripts/release_preflight.sh [--allow-dirty] [--skip-tests]

Options:
  --allow-dirty   Skip the clean working-tree check.
  --skip-tests    Skip xcodebuild test (useful when iterating on release scripts only).
  -h, --help      Show this help text.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

allow_dirty=0
skip_tests=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty) allow_dirty=1; shift ;;
    --skip-tests) skip_tests=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

step() {
  printf '\n\033[1;34m==>\033[0m %s\n' "$1"
}

fail() {
  printf '\033[1;31merror:\033[0m %s\n' "$1" >&2
  exit 1
}

step "Checking working tree"
if [[ $allow_dirty -eq 0 ]] && ! git diff-index --quiet HEAD --; then
  fail "Working tree has uncommitted changes. Commit or stash, or rerun with --allow-dirty."
fi

step "Regenerating Xcode project"
command -v xcodegen >/dev/null 2>&1 || fail "xcodegen is not installed. brew install xcodegen."
xcodegen generate

step "Reading MARKETING_VERSION from project.yml"
marketing_version=$(awk '/^[[:space:]]*MARKETING_VERSION:/ {print $2; exit}' project.yml)
[[ -n "$marketing_version" ]] || fail "Could not read MARKETING_VERSION from project.yml."
printf '  MARKETING_VERSION = %s\n' "$marketing_version"

step "Verifying CHANGELOG.md mentions $marketing_version"
[[ -f CHANGELOG.md ]] || fail "CHANGELOG.md is missing."
if ! grep -qE "^## \[${marketing_version//./\\.}\]" CHANGELOG.md; then
  fail "CHANGELOG.md has no \"## [$marketing_version]\" section. Add an entry before tagging."
fi

step "Building app target (Debug, CODE_SIGNING_ALLOWED=NO)"
xcodebuild \
  -project SpotlightCaffeinate.xcodeproj \
  -scheme SpotlightCaffeinate \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

step "Building CLI target (Debug, CODE_SIGNING_ALLOWED=NO)"
xcodebuild \
  -project SpotlightCaffeinate.xcodeproj \
  -scheme SpotlightCaffeinateCLI \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

if [[ $skip_tests -eq 0 ]]; then
  step "Running test suite"
  xcodebuild \
    -project SpotlightCaffeinate.xcodeproj \
    -scheme SpotlightCaffeinate \
    -configuration Debug \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    test >/dev/null
else
  step "Skipping tests (--skip-tests)"
fi

step "Shell-linting scripts/"
for script in scripts/*.sh; do
  bash -n "$script"
done

step "Automated gates passed"
cat <<'EOF'

Manual checks still required before publishing 1.0:

  1. Install the signed build from scripts/package_signed_release.sh into /Applications
     and walk through docs/release-checklist.md end to end:
       - menu bar UI
       - Spotlight actions (start / stop / extend / restart / status)
       - Notifications prompt + completion alert
       - Launch at login toggle
       - Bundled CLI sync (start, status, extend, stop all reflect the same session)
       - Every automation trigger type (weekly / power / calendar)

  2. App Store Connect:
       - screenshots (main menu active/idle, presets, automations, settings)
       - pricing
       - App Privacy answers ("No data collected")
       - App Review notes
       - upload the archive from Xcode Organizer or Transporter

  3. GitHub release:
       - tag v<version> and push
       - attach SpotlightCaffeinate.zip and spotlight-caffeinate-cli.tar.gz
       - confirm .github/workflows/update-homebrew-tap.yml can push to
         TaylorFinklea/homebrew-tap (HOMEBREW_TAP_PAT secret configured)

  4. Post-publish verification:
       - brew install --cask TaylorFinklea/tap/spotlight-caffeinate
       - brew install TaylorFinklea/tap/spotlight-caffeinate-cli
       - curl -fsSL ... | tar -xz  (binary install)
EOF
