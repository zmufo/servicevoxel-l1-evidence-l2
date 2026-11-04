@echo off
REM L2 external review package / verify.bat (Windows)
REM Scope: byte-level hash recheck ONLY. Does NOT produce L2 conclusions.
REM Requires: verify_win.ps1 in the same folder, MANIFEST.sha256 in this folder.
chcp 65001 >nul
setlocal
set "HERE=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%verify_win.ps1" -RepoRoot "%HERE%"
set "RC=%ERRORLEVEL%"
echo.
echo verify.bat finished. Open verify_result.txt in this folder.
echo This is an OPERATION-LAYER hash recheck only, NOT L2 approval.
echo A blank receipt copy is created next to this file (see verify_result.txt).
exit /b %RC%
