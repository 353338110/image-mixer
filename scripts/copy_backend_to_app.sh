#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_BIN="$ROOT_DIR/backend/dist/imagemixer_backend"

if [[ ! -f "$BACKEND_BIN" ]]; then
  echo "Backend binary not found: $BACKEND_BIN"
  exit 1
fi

WIN_TARGET="$ROOT_DIR/frontend/build/windows/x64/runner/Release/backend"
MAC_DIR="$ROOT_DIR/frontend/build/macos/Build/Products/Release"
MAC_APP="$MAC_DIR/ImageMixer.app"
if [[ ! -d "$MAC_APP" ]]; then
  MAC_APP="$(find "$MAC_DIR" -maxdepth 1 -name "*.app" -print -quit)"
fi
MAC_TARGET="${MAC_APP}/Contents/Frameworks"
MAC_BACKEND_ENTITLEMENTS="$ROOT_DIR/frontend/macos/Runner/Backend.entitlements"
MAC_APP_ENTITLEMENTS="$ROOT_DIR/frontend/macos/Runner/Release.entitlements"

if [[ -d "$WIN_TARGET" ]]; then
  mkdir -p "$WIN_TARGET"
  cp -f "$BACKEND_BIN" "$WIN_TARGET/imagemixer_backend.exe"
  echo "Copied backend to Windows build: $WIN_TARGET/imagemixer_backend.exe"
fi

if [[ -n "$MAC_APP" && -d "$MAC_TARGET" ]]; then
  mkdir -p "$MAC_TARGET"
  cp -f "$BACKEND_BIN" "$MAC_TARGET/imagemixer_backend"
  chmod +x "$MAC_TARGET/imagemixer_backend"
  echo "Copied backend to macOS app: $MAC_TARGET/imagemixer_backend"

  if command -v codesign >/dev/null 2>&1; then
    if [[ -f "$MAC_BACKEND_ENTITLEMENTS" ]]; then
      codesign --force --sign - --entitlements "$MAC_BACKEND_ENTITLEMENTS" "$MAC_TARGET/imagemixer_backend" || true
    else
      codesign --force --sign - "$MAC_TARGET/imagemixer_backend" || true
    fi
    if [[ -f "$MAC_APP_ENTITLEMENTS" ]]; then
      codesign --force --sign - --entitlements "$MAC_APP_ENTITLEMENTS" "$MAC_APP" || true
    else
      codesign --force --sign - "$MAC_APP" || true
    fi
  fi
fi

echo "Copy done."
