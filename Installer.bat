@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Video Downloader Installer

set "NO_PAUSE=0"
set "ASSUME_YES=0"

:ParseArguments
if "%~1"=="" goto ArgumentsReady
if /I "%~1"=="--no-pause" set "NO_PAUSE=1"
if /I "%~1"=="--yes" set "ASSUME_YES=1"
shift
goto ParseArguments

:ArgumentsReady

set "ROOT=%~dp0"
set "APP_FILE=%ROOT%Video Downloader.pyw"
set "LOG=%ROOT%setup.log"
set "RUNTIME=%ROOT%.runtime"
set "DOWNLOADS=%RUNTIME%\downloads"
set "PYTHON_DIR=%RUNTIME%\python"
set "RUNTIME_PY=%PYTHON_DIR%\python.exe"
set "RUNTIME_PYW=%PYTHON_DIR%\pythonw.exe"
set "LOCAL_SITE=%PYTHON_DIR%\Lib\site-packages"
set "PIP_PYZ=%PYTHON_DIR%\pip.pyz"
set "VENV=%ROOT%.venv"
set "VENV_PY=%VENV%\Scripts\python.exe"
set "VENV_PYW=%VENV%\Scripts\pythonw.exe"
set "FFMPEG_DIR=%RUNTIME%\ffmpeg"
set "FFMPEG_EXE=%FFMPEG_DIR%\ffmpeg.exe"
set "FFPROBE_EXE=%FFMPEG_DIR%\ffprobe.exe"
set "DENO_DIR=%RUNTIME%\deno"
set "DENO_EXE=%DENO_DIR%\deno.exe"

set "PYTHON_VERSION=3.14.6"
set "PYSIDE_VERSION=6.11.1"
set "FFMPEG_VERSION=8.1.2"
set "DENO_VERSION=2.9.3"
set "PYPI_INDEX=https://pypi.org/simple"

set "FFMPEG_URL=https://github.com/GyanD/codexffmpeg/releases/download/8.1.2/ffmpeg-8.1.2-essentials_build.zip"
set "FFMPEG_SHA256=DB580001CAA24AC104C8CB856CD113A87B0A443F7BDF47D8C12B1D740584A2EC"

set "NATIVE_ARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "NATIVE_ARCH=%PROCESSOR_ARCHITEW6432%"
if /I "%NATIVE_ARCH%"=="AMD64" goto ArchitectureX64
if /I "%NATIVE_ARCH%"=="ARM64" goto ArchitectureArm64
set "FAIL_MESSAGE=This installer currently supports 64-bit and ARM64 Windows only."
goto Failed

:ArchitectureX64
set "ARCH=x64"
set "PYTHON_URL=https://www.python.org/ftp/python/3.14.6/python-3.14.6-embed-amd64.zip"
set "PYTHON_SHA256=DF901E84A896FF1EE720AD03377E0C8D8C2244FDA79808AEEAFF6316DF1CB75C"
set "DENO_URL=https://github.com/denoland/deno/releases/download/v2.9.3/deno-x86_64-pc-windows-msvc.zip"
set "DENO_SHA256=60343461AC5FE3A31F4EF12667F2946BB852E20655C8610AEB7E751E87F7DF3A"
goto ArchitectureReady

:ArchitectureArm64
set "ARCH=arm64"
set "PYTHON_URL=https://www.python.org/ftp/python/3.14.6/python-3.14.6-embed-arm64.zip"
set "PYTHON_SHA256=0A7E80914709A9F3EBFCCDB9D1D02A37E4DDB69BB7F80D6DF1A7E95D54AF9E58"
set "DENO_URL=https://github.com/denoland/deno/releases/download/v2.9.3/deno-aarch64-pc-windows-msvc.zip"
set "DENO_SHA256=BC668F199E4892F4447661F253178AF007A4D715B0FF67493573B0E0216389AE"

:ArchitectureReady
>>"%LOG%" echo.
>>"%LOG%" echo ============================================================
>>"%LOG%" echo Setup started: %DATE% %TIME%
>>"%LOG%" echo Project root: "%ROOT%"
>>"%LOG%" echo Native architecture: %NATIVE_ARCH%
>>"%LOG%" echo ============================================================

cls
echo.
echo  ==================================================
echo                VIDEO DOWNLOADER SETUP
echo  ==================================================
echo.
echo   This keeps the app and its dependencies inside
echo   this folder. It does not need administrator access.
echo.
echo      Python environment     runs the app
echo      PySide6                the app window
echo      yt-dlp and EJS         downloads videos
echo      ffmpeg and ffprobe     audio and HD video
echo      Deno                   current YouTube support
echo.
echo   Keep this window open until every check passes.
echo   The first setup can take a few minutes.
echo.
echo  ==================================================

if not exist "%APP_FILE%" (
    set "FAIL_MESSAGE=Video Downloader.pyw is missing from this folder."
    goto Failed
)

if not exist "%RUNTIME%" mkdir "%RUNTIME%" >>"%LOG%" 2>&1
if not exist "%RUNTIME%" (
    set "FAIL_MESSAGE=Could not create the local runtime folder."
    goto Failed
)
if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%" >>"%LOG%" 2>&1
if not exist "%DOWNLOADS%" (
    set "FAIL_MESSAGE=Could not create the local download folder."
    goto Failed
)

echo.
echo   [ STEP 1 / 5 ]   Private Python environment
echo.
call :ValidateVenv
if not errorlevel 1 (
    echo      Existing environment is valid. Keeping it.
    call :Log "Existing virtual environment passed validation."
    set "ENV_MODE=venv"
    set "APP_PY=%VENV_PY%"
    set "APP_PYW=%VENV_PYW%"
    goto PythonEnvironmentReady
)

call :ValidateEmbeddedPython
if not errorlevel 1 (
    if exist "%VENV%" rmdir /s /q "%VENV%" >>"%LOG%" 2>&1
    if exist "%VENV%" (
        set "FAIL_MESSAGE=An invalid old .venv folder could not be removed."
        goto Failed
    )
    echo      Existing private Python is valid. Keeping it.
    call :Log "Existing embedded CPython passed validation."
    set "ENV_MODE=embedded"
    set "APP_PY=%RUNTIME_PY%"
    set "APP_PYW=%RUNTIME_PYW%"
    goto PythonEnvironmentReady
)

call :FindBasePython
if defined BASE_PY goto BasePythonReady

echo      No compatible 64-bit CPython was found.
echo.
echo      This app supports Python 3.10 through 3.14.
echo      An older or unsupported version may stop it from working.
echo      Setup can place Python %PYTHON_VERSION% privately inside
echo      this folder. It will not replace your current Python,
echo      change PATH, change file associations, or need admin.
echo.
if "%ASSUME_YES%"=="1" (
    echo      Install private Python %PYTHON_VERSION% now? [Y/N]: Y
) else (
    choice /C YN /N /M "      Install private Python %PYTHON_VERSION% now? [Y/N]: "
    if errorlevel 2 goto Cancelled
)

echo.
echo      Downloading and preparing private Python...
call :InstallEmbedPy
if errorlevel 1 (
    set "FAIL_MESSAGE=Private Python could not be installed or verified."
    goto Failed
)
if exist "%VENV%" rmdir /s /q "%VENV%" >>"%LOG%" 2>&1
if exist "%VENV%" (
    set "FAIL_MESSAGE=An invalid old .venv folder could not be removed."
    goto Failed
)
set "ENV_MODE=embedded"
set "APP_PY=%RUNTIME_PY%"
set "APP_PYW=%RUNTIME_PYW%"
goto PythonEnvironmentReady

:BasePythonReady
call :DescribePython "%BASE_PY%"
echo      Creating the app's private environment...
call :CreateVenv
if errorlevel 1 (
    set "FAIL_MESSAGE=The private Python environment could not be created."
    goto Failed
)
set "ENV_MODE=venv"
set "APP_PY=%VENV_PY%"
set "APP_PYW=%VENV_PYW%"

:PythonEnvironmentReady
call :ValidateSelectedEnvironment
if errorlevel 1 (
    set "FAIL_MESSAGE=The private Python environment did not pass validation."
    goto Failed
)
echo      Done.

echo.
echo   [ STEP 2 / 5 ]   App components
echo.
echo      Installing or updating trusted packages from PyPI...
echo      Existing components are reused whenever possible.
call :InstallPythonPackages
if errorlevel 1 (
    set "FAIL_MESSAGE=PySide6, yt-dlp, or yt-dlp-ejs could not be installed."
    goto Failed
)
echo      Done.

echo.
echo   [ STEP 3 / 5 ]   ffmpeg and ffprobe
echo.
call :ValidateFfmpeg
if not errorlevel 1 (
    echo      Current local copies are valid. Keeping them.
    call :Log "Existing FFmpeg and FFprobe passed validation."
    goto FfmpegReady
)
echo      Downloading the verified local media tools...
call :InstallFfmpeg
if errorlevel 1 (
    set "FAIL_MESSAGE=ffmpeg or ffprobe could not be installed and verified."
    goto Failed
)
:FfmpegReady
echo      Done.

echo.
echo   [ STEP 4 / 5 ]   Deno
echo.
call :ValidateDeno
if not errorlevel 1 (
    echo      Current local copy is valid. Keeping it.
    call :Log "Existing Deno passed validation."
    goto DenoReady
)
echo      Downloading the verified local YouTube runtime...
call :InstallDeno
if errorlevel 1 (
    set "FAIL_MESSAGE=Deno could not be installed and verified."
    goto Failed
)
:DenoReady
echo      Done.

echo.
echo   [ STEP 5 / 5 ]   Final checks
echo.
echo      Testing every required component...
call :VerifyEverything
if errorlevel 1 (
    set "FAIL_MESSAGE=One or more final component checks failed."
    goto Failed
)
echo      Every check passed.

if exist "%DOWNLOADS%" rmdir /s /q "%DOWNLOADS%" >>"%LOG%" 2>&1
call :Log "Setup completed successfully."

echo.
echo  ==================================================
echo                ALL SET, YOU ARE READY
echo  ==================================================
echo.
echo   Double click "Video Downloader.pyw" to start.
echo.
echo   Run this installer again whenever you want to
echo   update yt-dlp or repair the app's local files.
echo.
echo   Setup details were saved to:
echo   "%LOG%"
echo.
call :PauseIfNeeded
exit /b 0

:Cancelled
call :Log "Setup cancelled by the user before private Python installation."
echo.
echo  ==================================================
echo                     SETUP CANCELLED
echo  ==================================================
echo.
echo   Nothing was installed outside this project folder.
echo   Run Installer.bat again whenever you are ready.
echo.
call :PauseIfNeeded
exit /b 1

:Failed
if not defined FAIL_MESSAGE set "FAIL_MESSAGE=Setup stopped because an unexpected error occurred."
call :Log "ERROR: %FAIL_MESSAGE%"
echo.
echo  ==================================================
echo                     SETUP STOPPED
echo  ==================================================
echo.
echo   %FAIL_MESSAGE%
echo.
echo   No success was reported because all checks did not pass.
echo   The detailed log is here:
echo.
echo   "%LOG%"
echo.
echo   Fix the listed problem, then run Installer.bat again.
echo.
call :PauseIfNeeded
exit /b 1


:FindBasePython
set "BASE_PY="
where py.exe >nul 2>nul
if errorlevel 1 goto FindPathPython
for %%V in (3.14 3.13 3.12 3.11 3.10) do call :TryPyTag %%V
if defined BASE_PY exit /b 0

:FindPathPython
for /f "delims=" %%P in ('where python.exe 2^>nul ^| findstr /V /I /C:"Microsoft\WindowsApps"') do call :TryPythonPath "%%P"
if defined BASE_PY exit /b 0
for /f "delims=" %%P in ('where python3.exe 2^>nul ^| findstr /V /I /C:"Microsoft\WindowsApps"') do call :TryPythonPath "%%P"
if defined BASE_PY exit /b 0

for %%P in (
    "%LocalAppData%\Programs\Python\Python314\python.exe"
    "%LocalAppData%\Programs\Python\Python313\python.exe"
    "%LocalAppData%\Programs\Python\Python312\python.exe"
    "%LocalAppData%\Programs\Python\Python311\python.exe"
    "%LocalAppData%\Programs\Python\Python310\python.exe"
    "%ProgramFiles%\Python314\python.exe"
    "%ProgramFiles%\Python313\python.exe"
    "%ProgramFiles%\Python312\python.exe"
    "%ProgramFiles%\Python311\python.exe"
    "%ProgramFiles%\Python310\python.exe"
) do call :TryPythonPath "%%~fP"
exit /b 0

:TryPyTag
if defined BASE_PY exit /b 0
py -0p 2>nul | findstr /I /C:":%~1" >nul
if errorlevel 1 exit /b 1
set "CANDIDATE_FILE=%RUNTIME%\python-candidate.txt"
py -%~1 -I -c "import sys; print(sys.executable)" >"%CANDIDATE_FILE%" 2>>"%LOG%"
if errorlevel 1 exit /b 1
set "CANDIDATE="
set /p "CANDIDATE="<"%CANDIDATE_FILE%"
del /f /q "%CANDIDATE_FILE%" >nul 2>nul
if not defined CANDIDATE exit /b 1
call :TryPythonPath "%CANDIDATE%"
exit /b %ERRORLEVEL%

:TryPythonPath
if defined BASE_PY exit /b 0
if "%~1"=="" exit /b 1
if not exist "%~1" exit /b 1
call :ValidatePython "%~1"
if errorlevel 1 exit /b 1
set "BASE_PY=%~1"
call :Log "Found compatible base CPython: %~1"
exit /b 0

:ValidatePython
if "%~1"=="" exit /b 1
if not exist "%~1" exit /b 1
"%~1" -I -c "import sys, struct, venv, ensurepip; ok = sys.implementation.name == 'cpython' and (3, 10) <= sys.version_info[:2] < (3, 15) and struct.calcsize('P') == 8; raise SystemExit(0 if ok else 1)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:ValidateEmbeddedPython
call :ValidateEmbeddedPythonAt "%PYTHON_DIR%"
exit /b %ERRORLEVEL%

:ValidateEmbeddedPythonAt
if "%~1"=="" exit /b 1
if not exist "%~1\python.exe" exit /b 1
if not exist "%~1\pythonw.exe" exit /b 1
if not exist "%~1\Lib\site-packages" exit /b 1
if not exist "%~1\pip.pyz" exit /b 1
"%~1\python.exe" -I -c "import sys, struct, site; ok = sys.implementation.name == 'cpython' and sys.version_info[:3] == (3, 14, 6) and struct.calcsize('P') == 8 and any(p.lower().endswith(r'lib\site-packages') for p in sys.path); raise SystemExit(0 if ok else 1)" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
"%~1\python.exe" -I "%~1\pip.pyz" --version >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:DescribePython
"%~1" -I -c "import sys, platform; print('Selected CPython ' + platform.python_version() + ' at ' + sys.executable)" >>"%LOG%" 2>&1
set "PYTHON_VERSION_FILE=%RUNTIME%\python-version.txt"
"%~1" -I -c "import platform; print(platform.python_version())" >"%PYTHON_VERSION_FILE%" 2>>"%LOG%"
set "PYTHON_DISPLAY_VERSION="
if exist "%PYTHON_VERSION_FILE%" set /p "PYTHON_DISPLAY_VERSION="<"%PYTHON_VERSION_FILE%"
del /f /q "%PYTHON_VERSION_FILE%" >nul 2>nul
if defined PYTHON_DISPLAY_VERSION echo      Using compatible Python %PYTHON_DISPLAY_VERSION%.
exit /b 0

:InstallEmbedPy
call :ValidateEmbeddedPython
if not errorlevel 1 exit /b 0

set "PYTHON_ARCHIVE=%DOWNLOADS%\python-%PYTHON_VERSION%-embed-%ARCH%.zip"
set "PYTHON_NEW=%RUNTIME%\python.new"
set "PIP_DOWNLOAD=%DOWNLOADS%\pip.pyz"
call :DownloadAndVerify "%PYTHON_URL%" "%PYTHON_ARCHIVE%" "%PYTHON_SHA256%"
if errorlevel 1 exit /b 1
call :DownloadAndVerify "https://bootstrap.pypa.io/pip/pip.pyz" "%PIP_DOWNLOAD%" "RECORD_ONLY"
if errorlevel 1 exit /b 1

if exist "%PYTHON_NEW%" rmdir /s /q "%PYTHON_NEW%" >>"%LOG%" 2>&1
set "ARCHIVE_FILE=%PYTHON_ARCHIVE%"
set "NEW_DIR=%PYTHON_NEW%"
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_FILE -DestinationPath $env:NEW_DIR -Force; $pth=Get-ChildItem -LiteralPath $env:NEW_DIR -Filter 'python*._pth' -File | Select-Object -First 1; if(-not $pth){throw 'Python archive did not contain its path configuration.'}; $lines=@(Get-Content -LiteralPath $pth.FullName | Where-Object { $_ -notmatch '^\s*#?\s*import site\s*$' -and $_ -notmatch '^\s*Lib\\site-packages\s*$' }); $lines += 'Lib\site-packages'; $lines += 'import site'; Set-Content -LiteralPath $pth.FullName -Value $lines -Encoding ASCII; New-Item -ItemType Directory -Path (Join-Path $env:NEW_DIR 'Lib\site-packages') -Force | Out-Null; Copy-Item -LiteralPath $env:PIP_DOWNLOAD -Destination (Join-Path $env:NEW_DIR 'pip.pyz') -Force" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

call :ValidateEmbeddedPythonAt "%PYTHON_NEW%"
set "TEMP_VALIDATE_CODE=%ERRORLEVEL%"
if not "%TEMP_VALIDATE_CODE%"=="0" exit /b 1

call :ReplaceDirectory "%PYTHON_NEW%" "%PYTHON_DIR%"
if errorlevel 1 exit /b 1
del /f /q "%PYTHON_ARCHIVE%" "%PIP_DOWNLOAD%" >nul 2>nul
call :ValidateEmbeddedPython
if errorlevel 1 exit /b 1
call :Log "Official embedded CPython passed local validation."
exit /b 0

:ValidateSelectedEnvironment
if /I "%ENV_MODE%"=="venv" goto ValidateSelectedVenv
if /I "%ENV_MODE%"=="embedded" goto ValidateSelectedEmbedded
exit /b 1

:ValidateSelectedVenv
call :ValidateVenv
exit /b %ERRORLEVEL%

:ValidateSelectedEmbedded
call :ValidateEmbeddedPython
exit /b %ERRORLEVEL%

:ValidateVenv
if not exist "%VENV_PY%" exit /b 1
if not exist "%VENV_PYW%" exit /b 1
"%VENV_PY%" -I -c "import sys, struct; ok = sys.implementation.name == 'cpython' and (3, 10) <= sys.version_info[:2] < (3, 15) and struct.calcsize('P') == 8 and sys.prefix != sys.base_prefix; raise SystemExit(0 if ok else 1)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:CreateVenv
if not defined BASE_PY exit /b 1
call :ValidatePython "%BASE_PY%"
if errorlevel 1 exit /b 1

if exist "%VENV%" rmdir /s /q "%VENV%" >>"%LOG%" 2>&1
if exist "%VENV%" exit /b 1

call :Log "Creating virtual environment with: %BASE_PY%"
"%BASE_PY%" -I -m venv --copies "%VENV%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :ValidateVenv
exit /b %ERRORLEVEL%

:InstallPythonPackages
if not defined APP_PY exit /b 1
if not exist "%APP_PY%" exit /b 1
if /I "%ENV_MODE%"=="venv" goto InstallVenvPackages
if /I "%ENV_MODE%"=="embedded" goto InstallEmbeddedPackages
exit /b 1

:InstallVenvPackages
"%APP_PY%" -I -m pip --version >>"%LOG%" 2>&1
if not errorlevel 1 goto PipReady
call :Log "pip was missing; attempting ensurepip repair."
"%APP_PY%" -I -m ensurepip --upgrade >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

:PipReady
"%APP_PY%" -I -m pip --isolated --disable-pip-version-check install --upgrade --no-cache-dir --only-binary=:all: --index-url "%PYPI_INDEX%" pip >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :Log "Installing PySide6 %PYSIDE_VERSION% and current yt-dlp default dependencies from official PyPI."
"%APP_PY%" -I -m pip --isolated --disable-pip-version-check install --upgrade --no-cache-dir --only-binary=:all: --index-url "%PYPI_INDEX%" "PySide6==%PYSIDE_VERSION%" "yt-dlp[default]" >>"%LOG%" 2>&1
set "PACKAGE_INSTALL_CODE=%ERRORLEVEL%"
goto CheckInstalledPackages

:InstallEmbeddedPackages
call :ValidateEmbeddedPython
if errorlevel 1 exit /b 1
call :HasPinnedPySide
if errorlevel 1 goto InstallFullEmbeddedPackages
call :Log "Keeping verified PySide6 %PYSIDE_VERSION% and updating only yt-dlp default dependencies."
"%APP_PY%" -I "%PIP_PYZ%" --isolated --disable-pip-version-check install --upgrade --no-cache-dir --only-binary=:all: --index-url "%PYPI_INDEX%" --target "%LOCAL_SITE%" "yt-dlp[default]" >>"%LOG%" 2>&1
set "PACKAGE_INSTALL_CODE=%ERRORLEVEL%"
goto CheckInstalledPackages

:InstallFullEmbeddedPackages
call :Log "Installing PySide6 %PYSIDE_VERSION% and current yt-dlp default dependencies into embedded CPython from official PyPI."
"%APP_PY%" -I "%PIP_PYZ%" --isolated --disable-pip-version-check install --upgrade --no-cache-dir --only-binary=:all: --index-url "%PYPI_INDEX%" --target "%LOCAL_SITE%" "PySide6==%PYSIDE_VERSION%" "yt-dlp[default]" >>"%LOG%" 2>&1
set "PACKAGE_INSTALL_CODE=%ERRORLEVEL%"

:CheckInstalledPackages
if not "%PACKAGE_INSTALL_CODE%"=="0" goto RepairPythonPackages
call :VerifyPythonPackages
if not errorlevel 1 exit /b 0

:RepairPythonPackages
echo      A component check failed. Repairing local packages...
call :Log "Initial package validation failed; forcing a clean package reinstall."
if /I "%ENV_MODE%"=="venv" goto RepairVenvPackages
if /I "%ENV_MODE%"=="embedded" goto RepairEmbeddedPackages
exit /b 1

:RepairVenvPackages
"%APP_PY%" -I -m pip --isolated --disable-pip-version-check install --upgrade --force-reinstall --no-cache-dir --only-binary=:all: --index-url "%PYPI_INDEX%" "PySide6==%PYSIDE_VERSION%" "yt-dlp[default]" >>"%LOG%" 2>&1
goto RepairPackagesFinished

:RepairEmbeddedPackages
"%APP_PY%" -I "%PIP_PYZ%" --isolated --disable-pip-version-check install --upgrade --force-reinstall --no-cache-dir --only-binary=:all: --index-url "%PYPI_INDEX%" --target "%LOCAL_SITE%" "PySide6==%PYSIDE_VERSION%" "yt-dlp[default]" >>"%LOG%" 2>&1

:RepairPackagesFinished
if errorlevel 1 exit /b 1
call :VerifyPythonPackages
exit /b %ERRORLEVEL%

:VerifyPythonPackages
if not defined APP_PY exit /b 1
if not exist "%APP_PY%" exit /b 1
"%APP_PY%" -I -c "import PySide6, yt_dlp; from importlib.metadata import version; assert version('PySide6') == '%PYSIDE_VERSION%'; ejs = version('yt-dlp-ejs'); print('PySide6=' + version('PySide6')); print('yt-dlp=' + version('yt-dlp')); print('yt-dlp-ejs=' + ejs)" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
if /I "%ENV_MODE%"=="venv" goto CheckVenvDependencies
if /I "%ENV_MODE%"=="embedded" goto CheckEmbeddedDependencies
exit /b 1

:CheckVenvDependencies
"%APP_PY%" -I -m pip --isolated --disable-pip-version-check check >>"%LOG%" 2>&1
goto DependencyCheckFinished

:CheckEmbeddedDependencies
"%APP_PY%" -I "%PIP_PYZ%" --isolated --disable-pip-version-check check >>"%LOG%" 2>&1

:DependencyCheckFinished
if errorlevel 1 exit /b 1
"%APP_PY%" -I -m yt_dlp --ignore-config --version >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:HasPinnedPySide
if not defined APP_PY exit /b 1
if not exist "%APP_PY%" exit /b 1
"%APP_PY%" -I -c "import PySide6; from importlib.metadata import version; raise SystemExit(0 if version('PySide6') == '%PYSIDE_VERSION%' else 1)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:ValidateFfmpeg
if not exist "%FFMPEG_EXE%" exit /b 1
if not exist "%FFPROBE_EXE%" exit /b 1
set "FFMPEG_CHECK=%RUNTIME%\ffmpeg-check.txt"
"%FFMPEG_EXE%" -version >"%FFMPEG_CHECK%" 2>&1
if errorlevel 1 exit /b 1
findstr /B /C:"ffmpeg version %FFMPEG_VERSION%" "%FFMPEG_CHECK%" >nul
if errorlevel 1 exit /b 1
type "%FFMPEG_CHECK%" >>"%LOG%"
"%FFPROBE_EXE%" -version >"%FFMPEG_CHECK%" 2>&1
if errorlevel 1 exit /b 1
findstr /B /C:"ffprobe version %FFMPEG_VERSION%" "%FFMPEG_CHECK%" >nul
if errorlevel 1 exit /b 1
type "%FFMPEG_CHECK%" >>"%LOG%"
del /f /q "%FFMPEG_CHECK%" >nul 2>nul
exit /b 0

:InstallFfmpeg
set "FFMPEG_ARCHIVE=%DOWNLOADS%\ffmpeg-%FFMPEG_VERSION%.zip"
set "FFMPEG_EXTRACT=%RUNTIME%\ffmpeg.extract"
set "FFMPEG_NEW=%RUNTIME%\ffmpeg.new"
call :DownloadAndVerify "%FFMPEG_URL%" "%FFMPEG_ARCHIVE%" "%FFMPEG_SHA256%"
if errorlevel 1 exit /b 1

if exist "%FFMPEG_EXTRACT%" rmdir /s /q "%FFMPEG_EXTRACT%" >>"%LOG%" 2>&1
if exist "%FFMPEG_NEW%" rmdir /s /q "%FFMPEG_NEW%" >>"%LOG%" 2>&1
set "ARCHIVE_FILE=%FFMPEG_ARCHIVE%"
set "EXTRACT_DIR=%FFMPEG_EXTRACT%"
set "NEW_DIR=%FFMPEG_NEW%"
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_FILE -DestinationPath $env:EXTRACT_DIR -Force; $ff=Get-ChildItem -LiteralPath $env:EXTRACT_DIR -Filter ffmpeg.exe -File -Recurse | Select-Object -First 1; $fp=Get-ChildItem -LiteralPath $env:EXTRACT_DIR -Filter ffprobe.exe -File -Recurse | Select-Object -First 1; if(-not $ff -or -not $fp){throw 'FFmpeg archive did not contain both required programs.'}; New-Item -ItemType Directory -Path $env:NEW_DIR -Force | Out-Null; Copy-Item -LiteralPath $ff.FullName -Destination (Join-Path $env:NEW_DIR 'ffmpeg.exe') -Force; Copy-Item -LiteralPath $fp.FullName -Destination (Join-Path $env:NEW_DIR 'ffprobe.exe') -Force" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

set "OLD_FFMPEG_DIR=%FFMPEG_DIR%"
set "FFMPEG_DIR=%FFMPEG_NEW%"
set "FFMPEG_EXE=%FFMPEG_NEW%\ffmpeg.exe"
set "FFPROBE_EXE=%FFMPEG_NEW%\ffprobe.exe"
call :ValidateFfmpeg
set "TEMP_VALIDATE_CODE=%ERRORLEVEL%"
set "FFMPEG_DIR=%OLD_FFMPEG_DIR%"
set "FFMPEG_EXE=%FFMPEG_DIR%\ffmpeg.exe"
set "FFPROBE_EXE=%FFMPEG_DIR%\ffprobe.exe"
if not "%TEMP_VALIDATE_CODE%"=="0" exit /b 1

call :ReplaceDirectory "%FFMPEG_NEW%" "%FFMPEG_DIR%"
if errorlevel 1 exit /b 1
if exist "%FFMPEG_EXTRACT%" rmdir /s /q "%FFMPEG_EXTRACT%" >>"%LOG%" 2>&1
del /f /q "%FFMPEG_ARCHIVE%" >nul 2>nul
call :ValidateFfmpeg
exit /b %ERRORLEVEL%

:ValidateDeno
if not exist "%DENO_EXE%" exit /b 1
set "DENO_CHECK=%RUNTIME%\deno-check.txt"
"%DENO_EXE%" --version >"%DENO_CHECK%" 2>&1
if errorlevel 1 exit /b 1
findstr /B /C:"deno %DENO_VERSION%" "%DENO_CHECK%" >nul
if errorlevel 1 exit /b 1
type "%DENO_CHECK%" >>"%LOG%"
del /f /q "%DENO_CHECK%" >nul 2>nul
"%DENO_EXE%" eval "if (Deno.version.deno !== '%DENO_VERSION%') Deno.exit(1)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:InstallDeno
set "DENO_ARCHIVE=%DOWNLOADS%\deno-%DENO_VERSION%-%ARCH%.zip"
set "DENO_NEW=%RUNTIME%\deno.new"
call :DownloadAndVerify "%DENO_URL%" "%DENO_ARCHIVE%" "%DENO_SHA256%"
if errorlevel 1 exit /b 1

if exist "%DENO_NEW%" rmdir /s /q "%DENO_NEW%" >>"%LOG%" 2>&1
set "ARCHIVE_FILE=%DENO_ARCHIVE%"
set "NEW_DIR=%DENO_NEW%"
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_FILE -DestinationPath $env:NEW_DIR -Force; if(-not (Test-Path -LiteralPath (Join-Path $env:NEW_DIR 'deno.exe'))){throw 'Deno archive did not contain deno.exe.'}" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

set "OLD_DENO_DIR=%DENO_DIR%"
set "DENO_DIR=%DENO_NEW%"
set "DENO_EXE=%DENO_NEW%\deno.exe"
call :ValidateDeno
set "TEMP_VALIDATE_CODE=%ERRORLEVEL%"
set "DENO_DIR=%OLD_DENO_DIR%"
set "DENO_EXE=%DENO_DIR%\deno.exe"
if not "%TEMP_VALIDATE_CODE%"=="0" exit /b 1

call :ReplaceDirectory "%DENO_NEW%" "%DENO_DIR%"
if errorlevel 1 exit /b 1
del /f /q "%DENO_ARCHIVE%" >nul 2>nul
call :ValidateDeno
exit /b %ERRORLEVEL%

:ReplaceDirectory
set "REPLACE_NEW=%~1"
set "REPLACE_TARGET=%~2"
set "REPLACE_BACKUP=%~2.old"
if not exist "%REPLACE_NEW%" exit /b 1
if exist "%REPLACE_BACKUP%" rmdir /s /q "%REPLACE_BACKUP%" >>"%LOG%" 2>&1
if exist "%REPLACE_BACKUP%" exit /b 1
if not exist "%REPLACE_TARGET%" goto ReplaceMoveNew
move "%REPLACE_TARGET%" "%REPLACE_BACKUP%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

:ReplaceMoveNew
move "%REPLACE_NEW%" "%REPLACE_TARGET%" >>"%LOG%" 2>&1
if errorlevel 1 goto ReplaceRollback
if exist "%REPLACE_BACKUP%" rmdir /s /q "%REPLACE_BACKUP%" >>"%LOG%" 2>&1
exit /b 0

:ReplaceRollback
if exist "%REPLACE_TARGET%" rmdir /s /q "%REPLACE_TARGET%" >>"%LOG%" 2>&1
if exist "%REPLACE_BACKUP%" move "%REPLACE_BACKUP%" "%REPLACE_TARGET%" >>"%LOG%" 2>&1
exit /b 1

:DownloadAndVerify
set "DL_URL=%~1"
set "DL_FILE=%~2"
set "DL_HASH=%~3"
if /I "%DL_HASH%"=="RECORD_ONLY" set "DL_HASH="
if not defined DL_HASH goto DownloadFresh
if not exist "%DL_FILE%" goto DownloadFresh
call :VerifyFileHash "%DL_FILE%" "%DL_HASH%"
if not errorlevel 1 (
    call :Log "Reusing an already downloaded file that passed SHA-256 verification: %DL_FILE%"
    exit /b 0
)
del /f /q "%DL_FILE%" >nul 2>nul

:DownloadFresh
if exist "%DL_FILE%" del /f /q "%DL_FILE%" >nul 2>nul
call :Log "Downloading: %DL_URL%"

where curl.exe >nul 2>nul
if errorlevel 1 goto DownloadWithPowerShell
curl.exe --fail --location --silent --show-error --retry 3 --retry-delay 2 --connect-timeout 30 --proto "=https" --proto-redir "=https" -o "%DL_FILE%" "%DL_URL%" >>"%LOG%" 2>&1
if not errorlevel 1 goto VerifyDownload
call :Log "curl failed; retrying with PowerShell."

:DownloadWithPowerShell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $env:DL_URL -OutFile $env:DL_FILE" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

:VerifyDownload
if not exist "%DL_FILE%" exit /b 1
call :VerifyFileHash "%DL_FILE%" "%DL_HASH%"
exit /b %ERRORLEVEL%

:VerifyFileHash
set "VERIFY_FILE=%~1"
set "VERIFY_HASH=%~2"
if not exist "%VERIFY_FILE%" exit /b 1
if not defined VERIFY_HASH call :Log "Publisher does not provide a stable pip.pyz checksum; recording the SHA-256 received over HTTPS."
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $stream=[IO.File]::OpenRead($env:VERIFY_FILE); try{$sha=[Security.Cryptography.SHA256]::Create(); try{$actual=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')} finally{$sha.Dispose()}} finally{$stream.Dispose()}; if([string]::IsNullOrWhiteSpace($env:VERIFY_HASH)){Write-Output ('Recorded SHA-256: ' + $actual); exit 0}; if($actual -ne $env:VERIFY_HASH){throw ('SHA-256 mismatch. Expected {0}, got {1}' -f $env:VERIFY_HASH,$actual)}; Write-Output ('Verified SHA-256: ' + $actual)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:VerifyEverything
if not defined APP_PY exit /b 1
if not defined APP_PYW exit /b 1
if not exist "%APP_PY%" exit /b 1
if not exist "%APP_PYW%" exit /b 1
call :ValidateSelectedEnvironment
if errorlevel 1 exit /b 1
call :VerifyPythonPackages
if errorlevel 1 exit /b 1
call :ValidateFfmpeg
if errorlevel 1 exit /b 1
call :ValidateDeno
if errorlevel 1 exit /b 1

"%APP_PY%" -I -c "import os; from pathlib import Path; app=Path(os.environ['APP_FILE']); assert app.is_file(); compile(app.read_text(encoding='utf-8'), str(app), 'exec'); print('Application source compiled successfully.')" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:Log
>>"%LOG%" echo [%DATE% %TIME%] %~1
exit /b 0

:PauseIfNeeded
if "%NO_PAUSE%"=="1" exit /b 0
pause
exit /b 0
