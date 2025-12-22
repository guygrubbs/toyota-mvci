@echo off
setlocal
REM Convenience wrapper for users who prefer CMD over PowerShell.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Install-MVCI.ps1"
endlocal

