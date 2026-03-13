@echo off
setlocal

set ROOT_DIR=%~dp0..
cd /d "%ROOT_DIR%\frontend"

flutter create . --platforms=windows,macos
flutter pub get

echo Frontend bootstrap completed.

