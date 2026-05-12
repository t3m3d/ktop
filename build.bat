@echo off
setlocal

echo [1/2] Selecting Windows platform...
copy /Y platform_win.k platform.k >nul

echo [2/2] Krypton native PE/COFF build...
kcc.exe -o ktop.exe run.k
if errorlevel 1 (
    echo ERROR: Krypton compilation failed.
    del /Q platform.k 2>nul
    exit /b 1
)
del /Q platform.k

echo Installing to C:\krypton\bin\...
copy /Y ktop.exe C:\krypton\bin\ktop.exe >nul
if errorlevel 1 ( echo WARNING: install failed, run as admin if needed )

echo Done! Launching...
ktop.exe
