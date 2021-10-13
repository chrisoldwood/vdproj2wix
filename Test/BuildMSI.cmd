@echo off
setlocal EnableDelayedExpansion

:handle_help_request
if /i "%~1" == "-?"     call :usage & exit /b 0
if /i "%~1" == "--help" call :usage & exit /b 0

:check_args
if /i "%~1" == "" call :usage & exit /b 1
if /i "%~1" == "--clean" call :clean & exit /b 0

where candle 2>nul
if !errorlevel! neq 0 (
    echo ERROR: candle not found on the PATH, adjust it to include WiX, e.g
    echo set PATH=%%PATH%%;C:\Program Files ^(x86^)\WiX Toolset v3.xx\bin
    exit /b 1
)

set source=%~1
set candleOutput=%~dpn1.wixobj

:build
candle %source%
if !errorlevel! neq 0 exit /b !errorlevel!

light %candleOutput%
if !errorlevel! neq 0 exit /b !errorlevel!

exit /b 0

:usage
echo.
echo Usage: %~n0 ^<filename.wxs^>
echo.
goto :eof

:clean
rd /s /q Debug 2> nul
rd /s /q Release 2> nul
del *.wixobj 2> nul
del *.wixpdb 2> nul
del *.msi 2> nul
del /ah *.suo 2> nul
goto :eof
