@echo off
setlocal

set ROOT_DIR=%~dp0..
cd /d "%ROOT_DIR%\frontend"

call flutter create . --platforms=windows,macos
if errorlevel 1 exit /b 1

call flutter pub get
if errorlevel 1 exit /b 1

echo Frontend bootstrap completed.
