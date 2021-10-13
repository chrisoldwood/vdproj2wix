@echo off
setlocal EnableDelayedExpansion

call :run_test Test-FileSystem.vdproj
if !errorlevel! neq 0 goto :failure

:success
echo Tests PASSED
exit /b 0

:failure
echo Tests FAILED
exit /b 1

:run_test
set source=%~1
set output=%~dpn1.wxs
set expected=%~dpn1.expected.wxs
powershell.exe -File ..\vdproj2wix.ps1 %source%%
if !errorlevel! neq 0 exit /b !errorlevel!
fc %output% %expected%
if !errorlevel! neq 0 exit /b !errorlevel!
goto :eof
