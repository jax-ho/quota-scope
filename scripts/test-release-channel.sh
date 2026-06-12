#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "release-channel test failed: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$ROOT_DIR/$path" ]] || fail "missing $path"
}

assert_executable() {
  local path="$1"
  assert_file "$path"
  [[ -x "$ROOT_DIR/$path" ]] || fail "$path is not executable"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  grep -Eq -- "$pattern" "$ROOT_DIR/$path" || fail "$path does not contain /$pattern/"
}

assert_file "scripts/release-config.sh"
assert_executable "scripts/package-release.sh"
assert_executable "scripts/prepare-github-release-secrets.sh"
assert_executable "scripts/verify-release-environment.sh"
assert_file ".github/workflows/release.yml"
assert_file ".github/workflows/ci.yml"
assert_file "docs/release.md"

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/release-config.sh"

[[ "${APP_NAME:-}" == "QuotaScope" ]] || fail "APP_NAME should be QuotaScope"
[[ "${PROJECT_PATH:-}" == "CodexWatcher.xcodeproj" ]] || fail "PROJECT_PATH should point to the Xcode project"
[[ "${SCHEME_NAME:-}" == "CodexWatcher" ]] || fail "SCHEME_NAME should be CodexWatcher"
[[ "${HOST_BUNDLE_ID:-}" != local.* ]] || fail "HOST_BUNDLE_ID must be a stable non-local identifier"
[[ "${WIDGET_BUNDLE_ID:-}" == "${HOST_BUNDLE_ID}.widget" ]] || fail "WIDGET_BUNDLE_ID should derive from HOST_BUNDLE_ID"

if grep -R "local\\.quotascope" "$ROOT_DIR/CodexWatcher.xcodeproj" "$ROOT_DIR/Xcode" >/dev/null; then
  fail "Xcode project still contains local.quotascope bundle identifiers"
fi

assert_contains "CodexWatcher.xcodeproj/project.pbxproj" "PRODUCT_BUNDLE_IDENTIFIER = \"\\$\\(QUOTASCOPE_HOST_BUNDLE_ID\\)\""
assert_contains "CodexWatcher.xcodeproj/project.pbxproj" "PRODUCT_BUNDLE_IDENTIFIER = \"\\$\\(QUOTASCOPE_WIDGET_BUNDLE_ID\\)\""
assert_contains "Xcode/CodexWatcherHost/Info.plist" "\\$\\(MARKETING_VERSION\\)"
assert_contains "Xcode/CodexWatcherWidget/Info.plist" "\\$\\(MARKETING_VERSION\\)"

bash -n "$ROOT_DIR/scripts/release-config.sh"
bash -n "$ROOT_DIR/scripts/package-release.sh"

help_output="$("$ROOT_DIR/scripts/package-release.sh" --help)"
[[ "$help_output" == *"--version"* ]] || fail "package help should document --version"
[[ "$help_output" == *"--build-number"* ]] || fail "package help should document --build-number"
[[ "$help_output" == *"--skip-notarization"* ]] || fail "package help should document --skip-notarization"
[[ "$help_output" == *"--dry-run"* ]] || fail "package help should document --dry-run"
[[ "$help_output" == *"--export-unsigned"* ]] || fail "package help should document --export-unsigned"

dry_run_output="$("$ROOT_DIR/scripts/package-release.sh" --dry-run --version 9.9.9 --build-number 999 --skip-notarization --export-unsigned)"
[[ "$dry_run_output" == *"QuotaScope-9.9.9"* ]] || fail "dry-run should show versioned artifact names"
[[ "$dry_run_output" == *"notarization: skipped"* ]] || fail "dry-run should show notarization skip"
[[ "$dry_run_output" == *"export mode: unsigned"* ]] || fail "dry-run should show unsigned export mode"

signed_dry_run_output="$("$ROOT_DIR/scripts/package-release.sh" --dry-run --version 9.9.9 --build-number 999)"
[[ "$signed_dry_run_output" == *"export mode: Developer ID signed"* ]] || fail "signed dry-run should show Developer ID export mode"
[[ "$signed_dry_run_output" == *"notarization: enabled"* ]] || fail "signed dry-run should show notarization enabled"

secret_help_output="$("$ROOT_DIR/scripts/prepare-github-release-secrets.sh" --help)"
[[ "$secret_help_output" == *"APPLE_CERTIFICATE_BASE64"* ]] || fail "secret helper help should mention APPLE_CERTIFICATE_BASE64"
[[ "$secret_help_output" == *"--copy"* ]] || fail "secret helper help should document --copy"
[[ "$secret_help_output" == *"--dry-run"* ]] || fail "secret helper help should document --dry-run"
bash -n "$ROOT_DIR/scripts/prepare-github-release-secrets.sh"

secret_dry_run_output="$("$ROOT_DIR/scripts/prepare-github-release-secrets.sh" --dry-run "$ROOT_DIR/scripts/release-config.sh")"
[[ "$secret_dry_run_output" == *"would encode"* ]] || fail "secret helper dry-run should avoid printing secret material"
[[ "$secret_dry_run_output" != *"APP_NAME="* ]] || fail "secret helper dry-run should not print encoded input content"

environment_help_output="$("$ROOT_DIR/scripts/verify-release-environment.sh" --help)"
[[ "$environment_help_output" == *"Developer ID Application"* ]] || fail "environment verifier help should mention Developer ID Application"
[[ "$environment_help_output" == *"notarytool"* ]] || fail "environment verifier help should mention notarytool"
bash -n "$ROOT_DIR/scripts/verify-release-environment.sh"

assert_contains ".github/workflows/ci.yml" "on:[[:space:]]*$"
assert_contains ".github/workflows/ci.yml" "pull_request"
assert_contains ".github/workflows/ci.yml" "swift test"
assert_contains ".github/workflows/ci.yml" "scripts/test-release-channel.sh"
assert_contains ".github/workflows/ci.yml" "xcodebuild"
assert_contains ".github/workflows/ci.yml" "CODE_SIGNING_ALLOWED=NO"

assert_contains ".github/workflows/release.yml" "on:[[:space:]]*$"
assert_contains ".github/workflows/release.yml" "v\\*"
assert_contains ".github/workflows/release.yml" "distribution:"
assert_contains ".github/workflows/release.yml" "default: unsigned"
assert_contains ".github/workflows/release.yml" "--export-unsigned"
assert_contains ".github/workflows/release.yml" "--skip-notarization"
assert_contains ".github/workflows/release.yml" "APPLE_CERTIFICATE_BASE64"
assert_contains ".github/workflows/release.yml" "APPLE_CERTIFICATE_PASSWORD"
assert_contains ".github/workflows/release.yml" "APPLE_TEAM_ID"
assert_contains ".github/workflows/release.yml" "APPLE_ID"
assert_contains ".github/workflows/release.yml" "APPLE_APP_SPECIFIC_PASSWORD"
assert_contains ".github/workflows/release.yml" "scripts/package-release.sh"
assert_contains ".github/workflows/release.yml" "QuotaScope-.*\\.dmg"
assert_contains ".github/workflows/release.yml" "SHA256SUMS"

assert_contains "docs/release.md" "GitHub Releases"
assert_contains "docs/release.md" "Unsigned Release"
assert_contains "docs/release.md" "Developer ID Release"
assert_contains "docs/release.md" "Developer ID Application"
assert_contains "docs/release.md" "xcrun notarytool"
assert_contains "docs/release.md" "APPLE_CERTIFICATE_BASE64"
assert_contains "docs/release.md" "scripts/package-release.sh"
assert_contains "docs/release.md" "scripts/verify-release-environment.sh"

echo "release-channel tests passed"
