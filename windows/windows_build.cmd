@echo off
rem Works from the project root or from windows\
set "SCRIPT=%~dp0windows_build.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0windows\windows_build.ps1"
powershell -NoProfile -exec bypass -file "%SCRIPT%" %*
pause