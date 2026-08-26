@echo off
REM Launches build-debug.ps1 with the execution-policy check bypassed
REM for this one process only. No system-wide policy change, no
REM Unblock-File step needed. Any arguments you pass to this .bat
REM (e.g. -Clean, -Repo "D:\path") are forwarded to the script.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-debug.ps1" %*
