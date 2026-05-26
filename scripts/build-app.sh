#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Codex Watcher.app"
DERIVED_DATA_DIR="$ROOT_DIR/build/XcodeDerivedData"
BUILT_APP="$DERIVED_DATA_DIR/Build/Products/Debug/Codex Watcher.app"

cd "$ROOT_DIR"
xcodebuild \
  -project CodexWatcher.xcodeproj \
  -scheme CodexWatcher \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

rm -rf "$APP_DIR"
mkdir -p "$ROOT_DIR/dist"
cp -R "$BUILT_APP" "$APP_DIR"

echo "$APP_DIR"
