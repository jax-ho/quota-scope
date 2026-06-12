#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT_DIR/scripts/release-config.sh"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
CHECK_GITHUB=0
FAILURES=0

usage() {
  cat <<USAGE
Usage: scripts/verify-release-environment.sh [options]

Check whether this Mac is ready to produce a Developer ID signed and notarized
$APP_NAME release DMG with xcrun notarytool.

Options:
  --check-github         Also check that the GitHub CLI is installed and authenticated.
  --identity NAME        codesign identity to look for. Default: Developer ID Application.
  --help                Show this help.

Environment:
  SIGNING_IDENTITY, APPLE_TEAM_ID, APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD,
  NOTARY_KEYCHAIN_PROFILE.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-github)
      CHECK_GITHUB=1
      shift
      ;;
    --identity)
      [[ $# -ge 2 ]] || {
        echo "--identity requires a value" >&2
        exit 1
      }
      SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 1
      ;;
  esac
done

pass() {
  printf 'ok: %s\n' "$*"
}

fail() {
  printf 'missing: %s\n' "$*" >&2
  FAILURES=$((FAILURES + 1))
}

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 is available"
  else
    fail "$1 is not available"
  fi
}

check_full_xcode() {
  local developer_dir
  developer_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ -z "$developer_dir" ]]; then
    fail "xcode-select has no active developer directory"
    return
  fi
  if [[ "$developer_dir" == *CommandLineTools* ]]; then
    fail "active developer directory is Command Line Tools: $developer_dir"
    return
  fi
  if xcrun --find xcodebuild >/dev/null 2>&1; then
    pass "full Xcode is selected: $developer_dir"
  else
    fail "xcodebuild is not available from active Xcode: $developer_dir"
  fi
}

check_signing_identity() {
  if security find-identity -v -p codesigning 2>/dev/null | grep -F "$SIGNING_IDENTITY" >/dev/null; then
    pass "codesign identity is available: $SIGNING_IDENTITY"
  else
    fail "codesign identity not found: $SIGNING_IDENTITY"
  fi
}

check_notarization_credentials() {
  if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
    pass "notarytool keychain profile configured: $NOTARY_KEYCHAIN_PROFILE"
    return
  fi

  if [[ -n "$APPLE_TEAM_ID" && -n "$APPLE_ID" && -n "$APPLE_APP_SPECIFIC_PASSWORD" ]]; then
    pass "Apple ID notarization environment variables are configured"
  else
    fail "set NOTARY_KEYCHAIN_PROFILE or APPLE_TEAM_ID, APPLE_ID, and APPLE_APP_SPECIFIC_PASSWORD"
  fi
}

check_github_cli() {
  if [[ "$CHECK_GITHUB" -eq 0 ]]; then
    return
  fi
  if ! command -v gh >/dev/null 2>&1; then
    fail "gh is not installed"
    return
  fi
  if gh auth status >/dev/null 2>&1; then
    pass "gh is authenticated"
  else
    fail "gh is installed but not authenticated"
  fi
}

check_command xcrun
check_command hdiutil
check_command codesign
check_command security
check_command shasum
check_full_xcode
check_signing_identity
check_notarization_credentials
check_github_cli

if [[ "$FAILURES" -gt 0 ]]; then
  printf '\n%s release environment check failed with %d issue(s).\n' "$APP_NAME" "$FAILURES" >&2
  printf 'See docs/release.md for setup commands.\n' >&2
  exit 1
fi

printf '\n%s release environment is ready.\n' "$APP_NAME"
