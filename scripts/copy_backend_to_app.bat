@echo off
setlocal

set "ROOT_DIR=%~dp0.."
set "BACKEND_BIN=%ROOT_DIR%\backend\dist\imagemixer_backend.exe"
set "WIN_BUILD_DIR=%ROOT_DIR%\frontend\build\windows\x64\runner\Release"
set "WIN_TARGET=%WIN_BUILD_DIR%\backend"
set "MAC_TARGET=%ROOT_DIR%\frontend\build\macos\Build\Products\Release\ImageMixer.app\Contents\Frameworks"

if not exist "%BACKEND_BIN%" (
  echo Backend binary not found: %BACKEND_BIN%
  exit /b 1
)

if exist "%WIN_BUILD_DIR%" (
  if not exist "%WIN_TARGET%" mkdir "%WIN_TARGET%"
  copy /Y "%BACKEND_BIN%" "%WIN_TARGET%\imagemixer_backend.exe"
  if errorlevel 1 exit /b 1
  echo Copied backend to Windows build: %WIN_TARGET%\imagemixer_backend.exe
)

if exist "%MAC_TARGET%" (
  copy /Y "%BACKEND_BIN%" "%MAC_TARGET%\imagemixer_backend"
  if errorlevel 1 exit /b 1
  echo Copied backend to macOS app: %MAC_TARGET%\imagemixer_backend
)

echo Copy done.
