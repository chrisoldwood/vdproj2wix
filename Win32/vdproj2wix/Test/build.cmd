@echo off

if /i "%1" == "--clean" goto clean

:build
candle Test.wxs
if errorlevel 1 exit /b 1

light Test.wixobj
if errorlevel 1 exit /b 1

exit /b 0

:clean
del *.wixobj
del *.wixpdb
del *.msi

exit /b 0
