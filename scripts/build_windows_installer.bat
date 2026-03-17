@echo off
setlocal

set ROOT_DIR=%~dp0..
cd /d "%ROOT_DIR%"

if not exist "%ROOT_DIR%\dist" mkdir "%ROOT_DIR%\dist"

where /q iscc
if errorlevel 1 (
  echo Inno Setup (iscc) not found. Please install Inno Setup and add it to PATH.
  exit /b 1
)

set BUILD_DIR=%ROOT_DIR%\frontend\build\windows\x64\runner\Release
set BACKEND_EXE=%BUILD_DIR%\backend\imagemixer_backend.exe

if not exist "%BACKEND_EXE%" (
  echo Backend exe not found in build output. Copying backend into app...
  call "%ROOT_DIR%\scripts\copy_backend_to_app.bat"
)

if not exist "%BACKEND_EXE%" (
  echo Backend exe still missing: %BACKEND_EXE%
  exit /b 1
)

iscc /O"%ROOT_DIR%\dist" "%ROOT_DIR%\scripts\build_windows_installer.iss"

if not exist "%ROOT_DIR%\dist\ImageMixer-Setup.exe" (
  echo Installer not found: %ROOT_DIR%\dist\ImageMixer-Setup.exe
  dir /s /b "%ROOT_DIR%\*ImageMixer-Setup.exe"
  exit /b 1
)

echo Installer generated under %ROOT_DIR%\dist\
