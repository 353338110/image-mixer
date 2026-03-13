#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH."
  exit 1
fi

if [[ "$OSTYPE" == darwin* ]]; then
  echo "[1/4] Build backend"
  "$ROOT_DIR/scripts/build_backend.sh"

  echo "[2/4] Build Flutter macOS release"
  cd "$ROOT_DIR/frontend"
  flutter build macos --release
  cd "$ROOT_DIR"

  echo "[3/4] Copy backend into app bundle"
  "$ROOT_DIR/scripts/copy_backend_to_app.sh"

  echo "[4/4] Build DMG"
  "$ROOT_DIR/scripts/build_macos_dmg.sh"

  echo "Done: $ROOT_DIR/dist/ImageMixer-macos.dmg"
  exit 0
fi

echo "Unsupported OS for this script. Use Windows batch script on Windows."
exit 1
