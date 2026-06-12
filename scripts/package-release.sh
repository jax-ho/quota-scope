#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release-config.sh
source "$ROOT_DIR/scripts/release-config.sh"

VERSION="${RELEASE_VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
OUTPUT_DIR="$ROOT_DIR/$RELEASE_ROOT"
DERIVED_DATA_DIR="$ROOT_DIR/$BUILD_ROOT/DerivedData"
STAGING_DIR="$ROOT_DIR/$BUILD_ROOT/staging"
SIGNED_APP_DIR="$ROOT_DIR/$BUILD_ROOT/$APP_NAME.app"
SKIP_NOTARIZATION=0
DRY_RUN=0
EXPORT_UNSIGNED=0
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"

usage() {
  cat <<USAGE
Usage: scripts/package-release.sh [options]

Build a distributable macOS release for $APP_NAME.

Options:
  --version VERSION          Marketing version, for example 1.0.1.
  --build-number NUMBER     CFBundleVersion build number.
  --output-dir DIR          Directory for release artifacts. Default: $RELEASE_ROOT.
  --identity NAME           Developer ID signing identity. Default: Developer ID Application.
  --team-id TEAMID          Apple Developer Team ID. Can also use APPLE_TEAM_ID.
  --apple-id EMAIL          Apple ID for notarytool. Can also use APPLE_ID.
  --app-password PASSWORD   App-specific password for notarytool. Can also use APPLE_APP_SPECIFIC_PASSWORD.
  --keychain-profile NAME   notarytool keychain profile. Can also use NOTARY_KEYCHAIN_PROFILE.
  --skip-notarization       Build and sign the DMG without submitting it to Apple.
  --export-unsigned         Build an unsigned DMG for local smoke testing. Not for distribution.
  --dry-run                 Print resolved settings and planned steps without building.
  --help                    Show this help.

Environment overrides:
  APP_NAME, PROJECT_PATH, SCHEME_NAME, CONFIGURATION, HOST_BUNDLE_ID,
  WIDGET_BUNDLE_ID, RELEASE_ROOT, BUILD_ROOT, SIGNING_IDENTITY,
  APPLE_TEAM_ID, APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, NOTARY_KEYCHAIN_PROFILE.
USAGE
}

log() {
  printf '==> %s\n' "$*"
}

die() {
  printf 'package-release: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die "--version requires a value"
      VERSION="$2"
      shift 2
      ;;
    --build-number)
      [[ $# -ge 2 ]] || die "--build-number requires a value"
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || die "--output-dir requires a value"
      OUTPUT_DIR="$2"
      [[ "$OUTPUT_DIR" = /* ]] || OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
      shift 2
      ;;
    --identity)
      [[ $# -ge 2 ]] || die "--identity requires a value"
      SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --team-id)
      [[ $# -ge 2 ]] || die "--team-id requires a value"
      APPLE_TEAM_ID="$2"
      shift 2
      ;;
    --apple-id)
      [[ $# -ge 2 ]] || die "--apple-id requires a value"
      APPLE_ID="$2"
      shift 2
      ;;
    --app-password)
      [[ $# -ge 2 ]] || die "--app-password requires a value"
      APPLE_APP_SPECIFIC_PASSWORD="$2"
      shift 2
      ;;
    --keychain-profile)
      [[ $# -ge 2 ]] || die "--keychain-profile requires a value"
      NOTARY_KEYCHAIN_PROFILE="$2"
      shift 2
      ;;
    --skip-notarization)
      SKIP_NOTARIZATION=1
      shift
      ;;
    --export-unsigned)
      EXPORT_UNSIGNED=1
      SKIP_NOTARIZATION=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

project_marketing_version() {
  awk -F ' = ' '/MARKETING_VERSION = / {
    gsub(/;|"/, "", $2)
    print $2
    exit
  }' "$ROOT_DIR/$PROJECT_PATH/project.pbxproj"
}

git_tag_version() {
  local tag
  tag="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || true)"
  if [[ "$tag" == v* ]]; then
    printf '%s\n' "${tag#v}"
  fi
}

git_build_number() {
  git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M
}

resolve_defaults() {
  if [[ -z "$VERSION" ]]; then
    VERSION="$(git_tag_version)"
  fi
  if [[ -z "$VERSION" ]]; then
    VERSION="$(project_marketing_version)"
  fi
  if [[ -z "$VERSION" ]]; then
    die "could not resolve version; pass --version"
  fi

  if [[ -z "$BUILD_NUMBER" ]]; then
    BUILD_NUMBER="$(git_build_number)"
  fi

  ARTIFACT_PREFIX="$APP_NAME-$VERSION"
  DMG_PATH="$OUTPUT_DIR/$ARTIFACT_PREFIX.dmg"
  CHECKSUM_PATH="$OUTPUT_DIR/SHA256SUMS"
  RELEASE_NOTES_PATH="$OUTPUT_DIR/RELEASE_NOTES.md"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_full_xcode() {
  require_command xcrun
  local developer_dir
  developer_dir="$(xcode-select -p 2>/dev/null || true)"
  [[ -n "$developer_dir" ]] || die "xcode-select has no active developer directory"
  [[ "$developer_dir" != *CommandLineTools* ]] || die "xcodebuild requires full Xcode. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  xcrun --find xcodebuild >/dev/null 2>&1 || die "xcodebuild was not found in the active Xcode"
}

validate_release_inputs() {
  [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}([-.][A-Za-z0-9]+)?$ ]] || die "version '$VERSION' should look like 1.2.3"
  [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "build number '$BUILD_NUMBER' must be numeric"
  [[ "$HOST_BUNDLE_ID" != local.* ]] || die "HOST_BUNDLE_ID must not use the local.* namespace"
  [[ "$WIDGET_BUNDLE_ID" == "$HOST_BUNDLE_ID.widget" ]] || die "WIDGET_BUNDLE_ID should be HOST_BUNDLE_ID.widget"

  if [[ "$DRY_RUN" -eq 0 && "$EXPORT_UNSIGNED" -eq 0 ]]; then
    [[ -n "$SIGNING_IDENTITY" ]] || die "SIGNING_IDENTITY or --identity is required"
  fi

  if [[ "$DRY_RUN" -eq 0 && "$EXPORT_UNSIGNED" -eq 0 && "$SKIP_NOTARIZATION" -eq 0 && -z "$NOTARY_KEYCHAIN_PROFILE" ]]; then
    [[ -n "$APPLE_TEAM_ID" ]] || die "APPLE_TEAM_ID or --team-id is required for notarization"
    [[ -n "$APPLE_ID" ]] || die "APPLE_ID or --apple-id is required for notarization"
    [[ -n "$APPLE_APP_SPECIFIC_PASSWORD" ]] || die "APPLE_APP_SPECIFIC_PASSWORD or --app-password is required for notarization"
  fi
}

print_dry_run() {
  cat <<DRYRUN
release dry-run:
  app: $APP_NAME
  version: $VERSION
  build number: $BUILD_NUMBER
  artifact prefix: $ARTIFACT_PREFIX
  dmg: $DMG_PATH
  host bundle id: $HOST_BUNDLE_ID
  widget bundle id: $WIDGET_BUNDLE_ID
  project: $PROJECT_PATH
  scheme: $SCHEME_NAME
  configuration: $CONFIGURATION
  export mode: $([[ "$EXPORT_UNSIGNED" -eq 1 ]] && printf 'unsigned' || printf 'Developer ID signed')
  notarization: $([[ "$SKIP_NOTARIZATION" -eq 1 ]] && printf 'skipped' || printf 'enabled')
  steps:
    - validate release inputs
    - build Release app with xcodebuild
    - $([[ "$EXPORT_UNSIGNED" -eq 1 ]] && printf 'skip code signing for unsigned local export' || printf 'sign embedded WidgetKit extension and host app')
    - create compressed DMG with /Applications shortcut
    - submit DMG with xcrun notarytool unless skipped
    - staple notarization ticket unless skipped
    - write SHA256SUMS and RELEASE_NOTES.md
DRYRUN
}

build_app() {
  log "Building $APP_NAME $VERSION ($BUILD_NUMBER)"
  rm -rf "$DERIVED_DATA_DIR" "$SIGNED_APP_DIR"
  xcrun xcodebuild \
    -project "$ROOT_DIR/$PROJECT_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    QUOTASCOPE_HOST_BUNDLE_ID="$HOST_BUNDLE_ID" \
    QUOTASCOPE_WIDGET_BUNDLE_ID="$WIDGET_BUNDLE_ID" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY= \
    build

  local built_app="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
  [[ -d "$built_app" ]] || die "expected built app at $built_app"
  ditto "$built_app" "$SIGNED_APP_DIR"
}

sign_app() {
  if [[ "$EXPORT_UNSIGNED" -eq 1 ]]; then
    log "Skipping code signing for unsigned local export"
    return
  fi

  log "Signing embedded app extension"
  local appex="$SIGNED_APP_DIR/Contents/PlugIns/CodexWatcherWidgetExtension.appex"
  [[ -d "$appex" ]] || die "expected widget extension at $appex"
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --entitlements "$ROOT_DIR/Xcode/CodexWatcherWidget/CodexWatcherWidget.entitlements" \
    --sign "$SIGNING_IDENTITY" \
    "$appex"

  log "Signing host app"
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$SIGNING_IDENTITY" \
    "$SIGNED_APP_DIR"

  log "Verifying app signature"
  codesign --verify --deep --strict --verbose=2 "$SIGNED_APP_DIR"
}

create_dmg() {
  log "Creating DMG"
  rm -rf "$STAGING_DIR"
  mkdir -p "$STAGING_DIR" "$OUTPUT_DIR"
  ditto "$SIGNED_APP_DIR" "$STAGING_DIR/$APP_NAME.app"
  ln -s /Applications "$STAGING_DIR/Applications"
  rm -f "$DMG_PATH"

  hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

  if [[ "$EXPORT_UNSIGNED" -eq 0 ]]; then
    log "Signing DMG"
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    codesign --verify --verbose=2 "$DMG_PATH"
  fi
}

notarize_dmg() {
  if [[ "$EXPORT_UNSIGNED" -eq 1 ]]; then
    log "Skipping notarization for unsigned local export"
    return
  fi
  if [[ "$SKIP_NOTARIZATION" -eq 1 ]]; then
    log "Skipping notarization by request"
    return
  fi

  log "Submitting DMG for notarization"
  if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
    xcrun notarytool submit "$DMG_PATH" \
      --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
      --wait
  else
    xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
  fi

  log "Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
}

write_release_files() {
  log "Writing checksums and release notes"
  (
    cd "$OUTPUT_DIR"
    shasum -a 256 "$(basename "$DMG_PATH")" > "$CHECKSUM_PATH"
  )

  local distribution_note
  if [[ "$EXPORT_UNSIGNED" -eq 1 ]]; then
    distribution_note="Distribution: unsigned. macOS may ask internet downloaders to Control-click and choose Open."
  else
    distribution_note="Distribution: Developer ID signed and notarized."
  fi

  cat > "$RELEASE_NOTES_PATH" <<NOTES
# $APP_NAME $VERSION

Install by opening \`$(basename "$DMG_PATH")\` and dragging \`$APP_NAME.app\` to Applications.

Minimum macOS: $MIN_MACOS_VERSION
Build: $BUILD_NUMBER
$distribution_note

Verify the download:

\`\`\`sh
shasum -a 256 -c SHA256SUMS
\`\`\`
NOTES
}

main() {
  resolve_defaults
  validate_release_inputs

  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_dry_run
    exit 0
  fi

  require_full_xcode
  require_command ditto
  require_command hdiutil
  require_command codesign
  require_command shasum

  build_app
  sign_app
  create_dmg
  notarize_dmg
  write_release_files

  log "Release artifacts:"
  printf '  %s\n' "$DMG_PATH"
  printf '  %s\n' "$CHECKSUM_PATH"
  printf '  %s\n' "$RELEASE_NOTES_PATH"
}

main
