#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"

cd "$FRONTEND_DIR"
flutter pub get

if [[ "$OSTYPE" == darwin* ]]; then
  DEVICE="macos"
else
  DEVICE="windows"
fi

exec flutter run -d "$DEVICE"

