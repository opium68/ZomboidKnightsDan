@echo off
setlocal
chcp 65001 >nul
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  set "PZ_POWERSHELL=powershell.exe"
) else (
  set "PZ_POWERSHELL=pwsh.exe"
)
"%PZ_POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0join-server.ps1" -Reset
set "PZ_EXIT=%ERRORLEVEL%"
if not "%PZ_EXIT%"=="0" pause
exit /b %PZ_EXIT%
