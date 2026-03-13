@echo off
setlocal

set ROOT_DIR=%~dp0..
cd /d "%ROOT_DIR%\backend"

if not exist ".venv" (
  python -m venv .venv
)

call .venv\Scripts\activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

uvicorn app.main:app --host 127.0.0.1 --port 8765

