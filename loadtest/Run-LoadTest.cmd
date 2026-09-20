@echo off
setlocal

rem Uses the signed-in profile unless none is set; this repository's profile is tiketing-dev.
if "%AWS_PROFILE%"=="" set "AWS_PROFILE=tiketing-dev"

rem Codex desktop bundles Node.js, but does not add it to an ordinary PowerShell PATH.
if not exist "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" goto run
set "PATH=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin;%PATH%"

:run
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Ensure-K6.ps1"
if errorlevel 1 goto failed
if exist "%~dp0.tools\k6\k6.exe" set "PATH=%~dp0.tools\k6;%PATH%"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Invoke-LoadTest.ps1" %*
set "LOADTEST_EXIT=%ERRORLEVEL%"

if not "%LOADTEST_EXIT%"=="0" (
  echo.
  echo Load test stopped with exit code %LOADTEST_EXIT%. Review loadtest\results and the messages above.
  pause
)
endlocal & exit /b %LOADTEST_EXIT%

:failed
set "LOADTEST_EXIT=%ERRORLEVEL%"
echo.
echo k6 bootstrap failed with exit code %LOADTEST_EXIT%.
pause
endlocal & exit /b %LOADTEST_EXIT%
