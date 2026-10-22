@echo off
setlocal
if not exist "%~dp0kiosk-setup.ps1" (
  echo Missing kiosk-setup.ps1. Keep the setup files together.
  pause
  exit /b 1
)
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0kiosk-setup.ps1"
