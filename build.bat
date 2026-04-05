@echo off
setlocal

echo [1/3] Selecting Windows platform...
copy /Y platform_win.k platform.k >nul

echo [2/3] Krypton to C...
..\krypton\kcc.exe --headers ..\krypton\headers run.k > ktop_tmp.c
if errorlevel 1 (
    echo ERROR: Krypton compilation failed.
    del /Q ktop_tmp.c platform.k 2>nul
    exit /b 1
)

echo [3/3] C to exe...
gcc ktop_tmp.c -I. -o ktop.exe -lpsapi -lpdh -lm -w
if errorlevel 1 (
    echo ERROR: gcc failed.
    del /Q ktop_tmp.c platform.k 2>nul
    exit /b 1
)
del /Q ktop_tmp.c platform.k

echo Installing to C:\krypton\bin\...
copy /Y ktop.exe C:\krypton\bin\ktop.exe >nul
if errorlevel 1 ( echo WARNING: install failed, run as admin if needed )

echo Done! Launching...
ktop.exe
