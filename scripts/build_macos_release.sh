#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR/frontend"
flutter clean
flutter build macos --release
cd "$ROOT_DIR"

"$ROOT_DIR/scripts/copy_backend_to_app.sh"
"$ROOT_DIR/scripts/build_macos_dmg.sh"

echo "macOS release build + DMG done."
