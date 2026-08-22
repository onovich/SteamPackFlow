@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0InstallSteamCMD.ps1" %*
set "exit_code=%ERRORLEVEL%"
if not "%exit_code%"=="0" echo SteamCMD installation failed with exit code %exit_code%.
pause
exit /b %exit_code%
