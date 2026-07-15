@echo off
setlocal EnableDelayedExpansion
title Video Downloader Installer

cls
echo.
echo  ==================================================
echo                 VIDEO DOWNLOADER SETUP
echo  ==================================================
echo.
echo   Installing what the app needs:
echo.
echo      Python       runs the app
echo      PySide6      the app window
echo      yt-dlp       downloads the videos
echo      ffmpeg       audio and HD video
echo.
echo   Keep this window open until it says finished.
echo   The first install can take a few minutes.
echo.
echo  ==================================================

where winget >nul 2>nul
if errorlevel 1 goto NoWinget

call :FindPython

echo.
echo   [ STEP 1 / 3 ]   Python
echo.
if defined PYCMD (
    echo      Already installed, skipping.
) else (
    echo      Installing the latest Python, please wait...
    winget install --id Python.Python.3.14 --exact --source winget --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
    call :FindPython
)
if not defined PYCMD goto PythonMissing
echo      Done.

echo.
echo   [ STEP 2 / 3 ]   App components
echo.
echo      Installing PySide6 and yt-dlp, please wait...
echo      This is the largest step, a few minutes is normal.
%PYCMD% -m pip install --upgrade pip >nul 2>&1
%PYCMD% -m pip install --upgrade PySide6 yt-dlp >nul 2>&1
if errorlevel 1 goto ComponentsFailed
echo      Done.

echo.
echo   [ STEP 3 / 3 ]   ffmpeg
echo.
echo      Installing or updating ffmpeg, please wait...
winget install --id Gyan.FFmpeg --exact --source winget --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
winget upgrade --id Gyan.FFmpeg --exact --source winget --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
echo      Done.

echo.
echo  ==================================================
echo                ALL SET, YOU ARE READY
echo  ==================================================
echo.
echo   Double click "Video Downloader.pyw" to start.
echo.
pause
exit /b 0

:FindPython
set "PYCMD="
py -3 -V >nul 2>nul && set "PYCMD=py -3"
if not defined PYCMD (
    python -V >nul 2>nul && set "PYCMD=python"
)
if not defined PYCMD (
    for %%P in (
        "%LocalAppData%\Programs\Python\Python314\python.exe"
        "%LocalAppData%\Programs\Python\Python315\python.exe"
        "%LocalAppData%\Programs\Python\Python313\python.exe"
        "%ProgramFiles%\Python314\python.exe"
        "%ProgramFiles%\Python315\python.exe"
        "%ProgramFiles%\Python313\python.exe"
    ) do if exist "%%~P" set PYCMD="%%~fP"
)
exit /b

:PythonMissing
echo.
echo  ==================================================
echo                    SETUP PAUSED
echo  ==================================================
echo.
echo   Python is not ready in this window yet. This means
echo   either it needs a restart to be detected, or the
echo   download did not finish.
echo.
echo   Restart your PC, make sure you have internet, then
echo   run this installer one more time.
echo.
pause
exit /b 1

:ComponentsFailed
echo.
echo  ==================================================
echo                   SETUP STOPPED
echo  ==================================================
echo.
echo   Could not install the app components. This is
echo   almost always an internet issue.
echo.
echo   Check your connection and run the installer again.
echo.
pause
exit /b 1

:NoWinget
echo.
echo  ==================================================
echo                   ONE THING NEEDED
echo  ==================================================
echo.
echo   This installer needs the Windows tool called
echo   winget. It comes with Windows 11 and recent
echo   Windows 10.
echo.
echo   Open the Microsoft Store, search for App Installer,
echo   install or update it, then run this installer again.
echo.
pause
exit /b 1
