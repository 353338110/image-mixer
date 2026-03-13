@echo off
setlocal

set ROOT_DIR=%~dp0..
set BACKEND_BIN=%ROOT_DIR%\backend\dist\imagemixer_backend.exe

if not exist "%BACKEND_BIN%" (
  echo Backend binary not found: %BACKEND_BIN%
  exit /b 1
)

set WIN_TARGET=%ROOT_DIR%\frontend\build\windows\x64\runner\Release\backend
set MAC_TARGET=%ROOT_DIR%\frontend\build\macos\Build\Products\Release\ImageMixer.app\Contents\Frameworks

if exist "%WIN_TARGET%" (
  if not exist "%WIN_TARGET%" mkdir "%WIN_TARGET%"
  copy /Y "%BACKEND_BIN%" "%WIN_TARGET%\imagemixer_backend.exe"
  echo Copied backend to Windows build: %WIN_TARGET%\imagemixer_backend.exe
)

if exist "%MAC_TARGET%" (
  if not exist "%MAC_TARGET%" mkdir "%MAC_TARGET%"
  copy /Y "%BACKEND_BIN%" "%MAC_TARGET%\imagemixer_backend"
  echo Copied backend to macOS app: %MAC_TARGET%\imagemixer_backend
)

echo Copy done.
