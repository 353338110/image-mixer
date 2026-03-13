#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

cd "$BACKEND_DIR"

if [[ ! -d ".venv_pack" ]]; then
  python3 -m venv .venv_pack
fi

source .venv_pack/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller

pyinstaller --noconfirm --clean --onefile --name imagemixer_backend pack_entry.py

echo "Backend build done: $BACKEND_DIR/dist/imagemixer_backend"
