@echo off
setlocal

set ROOT_DIR=%~dp0..

start "ImageMixer Backend" cmd /k "%ROOT_DIR%\scripts\run_backend.bat"
timeout /t 3 >nul
call "%ROOT_DIR%\scripts\run_frontend.bat"

