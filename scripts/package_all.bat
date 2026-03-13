@echo off
setlocal

set ROOT_DIR=%~dp0..
cd /d "%ROOT_DIR%"

where /q flutter
if errorlevel 1 (
  echo flutter not found in PATH.
  exit /b 1
)

echo [1/4] Build backend
call "%ROOT_DIR%\scripts\build_backend.bat"

echo [2/4] Build Flutter windows release
cd /d "%ROOT_DIR%\frontend"
flutter build windows --release
cd /d "%ROOT_DIR%"

echo [3/4] Copy backend into app bundle
call "%ROOT_DIR%\scripts\copy_backend_to_app.bat"

echo [4/4] Build installer
call "%ROOT_DIR%\scripts\build_windows_installer.bat"

echo Done: %ROOT_DIR%\dist\ImageMixer-Setup.exe
