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
if errorlevel 1 exit /b 1

if not exist "%ROOT_DIR%\frontend\windows" (
  echo [2/5] Bootstrap Flutter desktop hosts
  call "%ROOT_DIR%\scripts\bootstrap_frontend.bat"
  if errorlevel 1 exit /b 1
)

echo [3/5] Build Flutter windows release
cd /d "%ROOT_DIR%\frontend"
call flutter build windows --release
if errorlevel 1 exit /b 1
cd /d "%ROOT_DIR%"

echo [4/5] Copy backend into app bundle
call "%ROOT_DIR%\scripts\copy_backend_to_app.bat"
if errorlevel 1 exit /b 1

echo [5/5] Build installer
call "%ROOT_DIR%\scripts\build_windows_installer.bat"
if errorlevel 1 exit /b 1

echo Done: %ROOT_DIR%\dist\ImageMixer-Setup.exe
