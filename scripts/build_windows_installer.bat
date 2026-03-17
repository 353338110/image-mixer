@echo off
setlocal

set "ROOT_DIR=%~dp0.."
cd /d "%ROOT_DIR%"

set "DIST_DIR=%ROOT_DIR%\dist"
set "BUILD_DIR=%ROOT_DIR%\frontend\build\windows\x64\runner\Release"
set "BACKEND_EXE=%BUILD_DIR%\backend\imagemixer_backend.exe"

echo ROOT_DIR=%ROOT_DIR%
echo DIST_DIR=%DIST_DIR%
echo BUILD_DIR=%BUILD_DIR%

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

where /q iscc
if errorlevel 1 (
  echo Inno Setup (iscc) not found. Please install Inno Setup and add it to PATH.
  exit /b 1
)

if not exist "%BACKEND_EXE%" (
  echo Backend exe not found in build output. Copying backend into app...
  call "%ROOT_DIR%\scripts\copy_backend_to_app.bat"
  if errorlevel 1 exit /b 1
)

if not exist "%BACKEND_EXE%" (
  echo Backend exe still missing: %BACKEND_EXE%
  dir /s /b "%BUILD_DIR%\*"
  exit /b 1
)

echo Running Inno Setup compiler...
iscc /O"%ROOT_DIR%\dist" "%ROOT_DIR%\scripts\build_windows_installer.iss"
if errorlevel 1 exit /b 1

echo Looking for generated installer...
dir /s /b "%ROOT_DIR%\*ImageMixer-Setup*.exe"

if not exist "%DIST_DIR%\ImageMixer-Setup.exe" (
  echo Installer not found: %DIST_DIR%\ImageMixer-Setup.exe
  exit /b 1
)

echo Installer generated under %DIST_DIR%\
