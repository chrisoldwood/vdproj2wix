@echo off

if /i "%1" == "--clean" goto clean

:build
candle Test.wxs
if errorlevel 1 exit /b 1

light Test.wixobj
if errorlevel 1 exit /b 1

exit /b 0

:clean
rd /s /q Debug 2> nul
rd /s /q Release 2> nul
del *.wixobj 2> nul
del *.wixpdb 2> nul
del *.msi 2> nul
del /ah *.suo 2> nul

exit /b 0
