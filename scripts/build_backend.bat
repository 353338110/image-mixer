@echo off
setlocal

set ROOT_DIR=%~dp0..
cd /d "%ROOT_DIR%\backend"

if not exist ".venv_pack" (
  python -m venv .venv_pack
)

call .venv_pack\Scripts\activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller

pyinstaller --noconfirm --clean --onefile --name imagemixer_backend pack_entry.py

echo Backend build done: %ROOT_DIR%\backend\dist\imagemixer_backend.exe
