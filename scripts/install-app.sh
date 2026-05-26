#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Codex Watcher.app"
INSTALL_DIR="$HOME/Applications"
INSTALL_APP="$INSTALL_DIR/Codex Watcher.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$ROOT_DIR/scripts/build-app.sh"

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_APP"
ditto "$APP_DIR" "$INSTALL_APP"
"$LSREGISTER" -f -R -trusted "$INSTALL_APP"
open "$INSTALL_APP"

echo "$INSTALL_APP"
