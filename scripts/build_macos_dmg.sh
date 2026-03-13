#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/frontend/build/macos/Build/Products/Release"
APP_PATH="$APP_DIR/ImageMixer.app"
OUT_DIR="$ROOT_DIR/dist"
OUT_DMG="$OUT_DIR/ImageMixer-macos.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$(find "$APP_DIR" -maxdepth 1 -name "*.app" -print -quit)"
fi

if [[ -z "${APP_PATH}" || ! -d "$APP_PATH" ]]; then
  echo "App not found under: $APP_DIR"
  exit 1
fi

mkdir -p "$OUT_DIR"
hdiutil create -volname "ImageMixer" -srcfolder "$APP_PATH" -ov -format UDZO "$OUT_DMG"

echo "DMG generated: $OUT_DMG"
