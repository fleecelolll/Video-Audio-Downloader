@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Video + Audio Downloader Setup
set "INSTALLER_SELF=%~f0"
set "INSTALLER_ROOT=%~dp0"

set "NO_PAUSE=0"
set "ASSUME_YES=0"
set "SETUP_CHILD=0"
set "LOG_READY="
set "DIAGNOSTIC_LOG=nul"
set "PATHS_VALIDATED="
set "REPAIR_HINT="
set "FFMPEG_DIR="
set "DENO_DIR="
set "HERCULES_DIR="
set "LUA_DIR="

:ParseArguments
if "%~1"=="" goto ArgumentsReady
if /I "%~1"=="--no-pause" goto ParseNoPause
if /I "%~1"=="--yes" goto ParseYes
if /I "%~1"=="--fleece-setup-child" goto ParseChildMarker
goto UnknownOption

:ParseChildMarker
if /I not "%FLEECE_TOOLS_INSTALLER_CHILD%"=="1" goto UnknownOption
set "SETUP_CHILD=1"
shift
goto ParseArguments

:UnknownOption
echo.
echo   Unknown setup option. No setup changes were made.
echo   Supported options: --yes --no-pause
echo.
exit /b 2

:ParseNoPause
set "NO_PAUSE=1"
shift
goto ParseArguments

:ParseYes
set "ASSUME_YES=1"
shift
goto ParseArguments

:ArgumentsReady
if "%SETUP_CHILD%"=="1" goto DedicatedChildReady
set "SETUP_CHILD_ARGS=--fleece-setup-child"
if "%ASSUME_YES%"=="1" set "SETUP_CHILD_ARGS=%SETUP_CHILD_ARGS% --yes"
if "%NO_PAUSE%"=="1" set "SETUP_CHILD_ARGS=%SETUP_CHILD_ARGS% --no-pause"
set "FLEECE_TOOLS_INSTALLER_CHILD=1"
"%SystemRoot%\System32\cmd.exe" /d /c call "%INSTALLER_SELF%" %SETUP_CHILD_ARGS%
exit /b %ERRORLEVEL%

:DedicatedChildReady
set "FLEECE_TOOLS_INSTALLER_CHILD="

set "ROOT=%INSTALLER_ROOT%"
set "MAX_ROOT_LENGTH=72"
set "APP_FILE=%ROOT%Video + Audio Downloader.pyw"
set "LOG=%ROOT%setup.log"
set "RUNTIME=%ROOT%.runtime"
set "SETUP_LOCK=%RUNTIME%\setup.lock"
set "SETUP_LOCK_OWNER=%SETUP_LOCK%\owner.json"
set "SETUP_MARKER=%RUNTIME%\setup-complete.txt"
set "SETUP_LOCK_HELD=0"
set "SETUP_LOCK_TOKEN="
set "SETUP_LOCK_MAX_AGE_MINUTES=60"
set "DOWNLOADS=%RUNTIME%\downloads"
set "PYTHON_DIR=%RUNTIME%\python"
set "RUNTIME_PY=%PYTHON_DIR%\python.exe"
set "RUNTIME_PYW=%PYTHON_DIR%\pythonw.exe"
set "LOCAL_SITE=%PYTHON_DIR%\Lib\site-packages"
set "PIP_WHEEL=%PYTHON_DIR%\pip.whl"
set "VENV=%ROOT%.venv"
set "FFMPEG_DIR=%RUNTIME%\ffmpeg"
set "FFMPEG_EXE=%FFMPEG_DIR%\ffmpeg.exe"
set "FFPROBE_EXE=%FFMPEG_DIR%\ffprobe.exe"
set "DENO_DIR=%RUNTIME%\deno"
set "DENO_EXE=%DENO_DIR%\deno.exe"
set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "CURL_EXE=%SystemRoot%\System32\curl.exe"
set "ROBOCOPY_EXE=%SystemRoot%\System32\robocopy.exe"
set "PYTHON_VERSION=3.14.7"
set "PYSIDE_VERSION=6.11.2"
set "PYSIDE_DISTRIBUTION=PySide6-Essentials"
set "PYPI_INDEX=https://pypi.org/simple"
set "PIP_WHEEL_URL=https://files.pythonhosted.org/packages/f3/6e/1736e5b4ae2b778ef2f81c47d797de9f891d4d8acb047a24ca37a60294dd/pip-26.2.1-py3-none-any.whl"
set "PIP_WHEEL_SHA256=71138ADF1F4CA900CDB7D289C21B7494329F2332B6D85F0E1C42108C0384ED3E"
set "YTDLP_VERSION=2026.8.19"
set "YTDLP_EJS_VERSION=0.8.0"
set "YTDLP_EJS_CORE_SHA256=18DA6CE0758B416E7AE645084F4F8801F9F9D59D6C477C05EAA0FF94EBD8CC00"
set "YTDLP_EJS_LIB_SHA256=C55987FE697E5B9EE18830163F7AF85327E9BB5C3E674B969D38C8D205EAA577"
set "CERTIFI_VERSION=2026.7.22"
set "CHARSET_NORMALIZER_VERSION=3.5.1"
set "IDNA_VERSION=3.20"
set "MUTAGEN_VERSION=1.48.1"
set "PYCRYPTODOMEX_VERSION=3.23.0"
set "REQUESTS_VERSION=2.34.2"
set "URLLIB3_VERSION=2.8.0"
set "WEBSOCKETS_VERSION=17.1"
set "BROTLI_VERSION=1.2.0"
set YTDLP_RUNTIME_PACKAGES="certifi==%CERTIFI_VERSION%" "charset-normalizer==%CHARSET_NORMALIZER_VERSION%" "idna==%IDNA_VERSION%" "mutagen==%MUTAGEN_VERSION%" "pycryptodomex==%PYCRYPTODOMEX_VERSION%" "requests==%REQUESTS_VERSION%" "urllib3==%URLLIB3_VERSION%" "websockets==%WEBSOCKETS_VERSION%"
set "YTDLP_ARCH_PACKAGE="
set "FFMPEG_VERSION=9.0.2"
set "DENO_VERSION=2.9.7"
set "FFMPEG_URL=https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.zip"
set "FFMPEG_SHA256=60F467265B1E312373DBCD92200C2618A74850F98D3D078E94296BB3FA2047BA"

set "NATIVE_ARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "NATIVE_ARCH=%PROCESSOR_ARCHITEW6432%"
if /I "%NATIVE_ARCH%"=="AMD64" goto ArchitectureX64
if /I "%NATIVE_ARCH%"=="ARM64" goto ArchitectureArm64
set "FAIL_MESSAGE=This installer currently supports 64-bit and ARM64 Windows only."
goto Failed

:ArchitectureX64
set "ARCH=x64"
set YTDLP_ARCH_PACKAGE="Brotli==%BROTLI_VERSION%"
set "PYTHON_URL=https://www.python.org/ftp/python/3.14.7/python-3.14.7-embed-amd64.zip"
set "PYTHON_SHA256=D297E5FF019966817AD8502465176139F2D3D840FA4ED84B13BED399A6AB1F15"
set "DENO_URL=https://github.com/denoland/deno/releases/download/v2.9.7/deno-x86_64-pc-windows-msvc.zip"
set "DENO_SHA256=A0C3101B4158D1DFB7D6A78A7BF0F3DE80C96BB423C152BEEC8BEB22786F2238"
goto ArchitectureReady

:ArchitectureArm64
set "ARCH=arm64"
set "PYTHON_URL=https://www.python.org/ftp/python/3.14.7/python-3.14.7-embed-arm64.zip"
set "PYTHON_SHA256=F6773983C8959D4281E48C4540CB0BDD23E42391E4E951CE17E7CEB52658F21C"
set "DENO_URL=https://github.com/denoland/deno/releases/download/v2.9.7/deno-aarch64-pc-windows-msvc.zip"
set "DENO_SHA256=C4C4AC8BFDAA37814BDA5C05FC9CDF2154904E2EF8277673A30BDCEAAA649807"

:ArchitectureReady
set "PIP_REQUIREMENTS=%ROOT%requirements-win-%ARCH%.txt"
if not exist "%POWERSHELL_EXE%" (
    set "FAIL_MESSAGE=Trusted Windows PowerShell is missing from the system folder."
    set "REPAIR_HINT=Repair Windows system components, then retry from a fresh official ZIP."
    goto Failed
)
if not exist "%ROBOCOPY_EXE%" (
    set "FAIL_MESSAGE=Trusted Windows file-copy support is missing from the system folder."
    set "REPAIR_HINT=Repair Windows system components, then retry from a fresh official ZIP."
    goto Failed
)
if not exist "%ROOT%LICENSE" (
    set "FAIL_MESSAGE=The bundled Tool License is missing from this folder. Extract a fresh official release and try again."
    set "REPAIR_HINT=Re-extract the complete official ZIP, including LICENSE, then run Installer.bat again."
    goto Failed
)
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "if([IO.Path]::GetFullPath($env:ROOT).Length -gt [int]$env:MAX_ROOT_LENGTH){exit 2}" >nul 2>nul
if errorlevel 1 (
    set "FAIL_MESSAGE=The complete app folder path must be 72 characters or fewer. Move the extracted folder closer to the drive root and try again."
    set "REPAIR_HINT=Move the complete folder to a short path such as C:\Tools\VideoDownloader, then retry."
    goto Failed
)
cls
echo.
echo   The app and private components stay inside this folder.
echo   The folder-local shortcut opens the private Python directly.
echo   Setup does not need administrator access.
echo.
echo      Python environment     runs the app
echo      PySide6                the app window
echo      yt-dlp and EJS         downloads videos
echo      FFmpeg and FFprobe     audio and HD video
echo      Deno                   current YouTube support
echo.
echo   Keep this window open until every check passes.
echo   The first setup can take a few minutes.
echo.
echo   Continue only if you accept the Terms and bundled Tool License.
echo   Terms: https://fleece.wtf/terms
echo   Tool License: LICENSE in this folder
echo.
echo  ==================================================
echo.
if "%ASSUME_YES%"=="1" (
    echo   Continue with install or repair? [Y/N]: Y
) else (
    choice /C YN /N /M "  Continue with install or repair? [Y/N]: "
    if errorlevel 2 goto Cancelled
)

:SetupApprovalReady
call :ValidatePrivatePaths
if errorlevel 1 (
    set "FAIL_MESSAGE=The app folder or one of its private setup paths is not safe to modify. Extract a fresh copy to a normal folder and try again."
    set "REPAIR_HINT=Re-extract to a normal local folder without links or junctions, then retry."
    goto Failed
)
set "PATHS_VALIDATED=1"
call :CheckRootWritePermission
if errorlevel 1 (
    set "FAIL_MESSAGE=Setup cannot write to this app folder. Move it to a folder owned by this Windows user and try again."
    set "REPAIR_HINT=Move the extracted folder to a location you can write to, then retry without administrator rights."
    goto Failed
)
if not exist "%RUNTIME%" mkdir "%RUNTIME%" >nul 2>nul
if not exist "%RUNTIME%" (
    set "FAIL_MESSAGE=Could not create the private runtime folder."
    goto Failed
)
call :AcquireSetupLock
if errorlevel 1 goto SetupAlreadyRunning

:PrepareSetupLog
if exist "%LOG%" del /f /q "%LOG%" >nul 2>nul
if exist "%LOG%" (
    set "FAIL_MESSAGE=The previous setup log could not be replaced safely."
    goto Failed
)
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$stream=[IO.File]::Open($env:LOG,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);$stream.Dispose()" >nul 2>nul
if errorlevel 1 (
    set "FAIL_MESSAGE=A fresh private setup log could not be created safely."
    goto Failed
)
set "LOG_READY=1"
set "DIAGNOSTIC_LOG=%LOG%"
call :EnsureAppClosed
if errorlevel 1 (
    set "FAIL_MESSAGE=Video + Audio Downloader is open. Close the app before installing or repairing its files."
    goto Failed
)
if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%" >>"%LOG%" 2>&1
if not exist "%DOWNLOADS%" (
    set "FAIL_MESSAGE=Could not create the private download folder."
    goto Failed
)

set "LOG_MESSAGE============================================================"
call :LogCurrent
set "LOG_MESSAGE=Setup started."
call :LogCurrent
set "LOG_MESSAGE=Project root: %ROOT%"
call :LogCurrent
set "LOG_MESSAGE=Native architecture: %NATIVE_ARCH%"
call :LogCurrent

if not exist "%APP_FILE%" (
    set "FAIL_MESSAGE=Video + Audio Downloader.pyw is missing from this folder."
    set "REPAIR_HINT=Re-extract the complete official ZIP, including the app source file, then run Installer.bat again."
    goto Failed
)
echo.
echo   [ PRE-DOWNLOAD CHECKS ]   App files and Windows setup support
call :CheckBundledSource
if errorlevel 1 (
    set "FAIL_MESSAGE=The bundled app source is empty, unreadable, or unsafe."
    set "REPAIR_HINT=Re-extract the complete official ZIP to a normal folder, then run Installer.bat again."
    goto Failed
)
call :CheckArchiveSupport
if errorlevel 1 (
    set "FAIL_MESSAGE=Windows PowerShell cannot extract ZIP archives in this session."
    set "REPAIR_HINT=Repair Windows PowerShell or its Microsoft.PowerShell.Archive module, then run Installer.bat again."
    goto Failed
)
call :CheckShortcutSupport
if errorlevel 1 (
    set "FAIL_MESSAGE=Windows could not create or read back a folder-local start shortcut."
    set "REPAIR_HINT=Remove a broken shortcut after saving it elsewhere, or repair Windows shortcut support, then retry."
    goto Failed
)
echo      Bundled source, ZIP extraction, and shortcut support passed.

echo.
echo   [ STEP 1 / 3 ]   Private Python environment
echo.
call :ValidateEmbeddedPython
if not errorlevel 1 (
    if exist "%VENV%" call :RemoveDirectoryRobust "%VENV%"
    if exist "%VENV%" (
        set "FAIL_MESSAGE=An old .venv folder could not be removed after private Python was verified."
        goto Failed
    )
    echo      Existing private Python is valid. Keeping it.
    set "LOG_MESSAGE=Existing embedded CPython passed validation."
    call :LogCurrent
    set "ENV_MODE=embedded"
    set "APP_PY=%RUNTIME_PY%"
    set "APP_PYW=%RUNTIME_PYW%"
    goto PythonEnvironmentReady
)

echo      No verified private Python runtime is available yet.
echo.

:ExplainEmbeddedPython
echo      Setup can place Python %PYTHON_VERSION% privately inside
echo      this folder. It will not replace your current Python,
echo      change PATH, install global packages, or need admin.
echo.
echo.
echo      Downloading and preparing private Python...
call :InstallEmbedPy
if errorlevel 1 (
    set "FAIL_MESSAGE=Private Python could not be installed or verified."
    set "REPAIR_HINT=Check free disk space and access to python.org and files.pythonhosted.org; inspect setup.log, then retry."
    goto Failed
)
if exist "%VENV%" call :RemoveDirectoryRobust "%VENV%"
if exist "%VENV%" (
    set "FAIL_MESSAGE=An invalid old .venv folder could not be removed."
    goto Failed
)
set "ENV_MODE=embedded"
set "APP_PY=%RUNTIME_PY%"
set "APP_PYW=%RUNTIME_PYW%"

:PythonEnvironmentReady
call :ValidateSelectedEnvironment
if errorlevel 1 (
    set "FAIL_MESSAGE=The private Python environment did not pass validation."
    goto Failed
)
echo      Done.

echo.
echo   [ STEP 2 / 3 ]   App components
echo.
echo      Installing or repairing trusted packages from PyPI...
echo      Existing components are reused whenever possible.
call :TouchSetupLock
if errorlevel 1 (
    set "FAIL_MESSAGE=Setup lost ownership of its private setup lock."
    goto Failed
)
call :InstallPythonPackages
if errorlevel 1 (
    set "FAIL_MESSAGE=PySide6, yt-dlp, or yt-dlp-ejs could not be installed and verified."
    set "REPAIR_HINT=Check access to pypi.org and files.pythonhosted.org; inspect setup.log for the failed package, then retry."
    goto Failed
)
call :TouchSetupLock
if errorlevel 1 (
    set "FAIL_MESSAGE=Setup lost ownership of its private setup lock."
    goto Failed
)
echo      Done.

echo.
echo      Installing or repairing FFmpeg and FFprobe...
echo.
call :TouchSetupLock
if errorlevel 1 (
    set "FAIL_MESSAGE=Setup lost ownership of its private setup lock."
    goto Failed
)
call :ValidateFfmpeg
if not errorlevel 1 (
    echo      Current local copies are valid. Keeping them.
    set "LOG_MESSAGE=Existing FFmpeg and FFprobe passed validation."
    call :LogCurrent
    goto FfmpegReady
)
echo      Downloading the verified local media tools...
call :InstallFfmpeg
if errorlevel 1 (
    set "FAIL_MESSAGE=FFmpeg or FFprobe could not be installed and verified."
    set "REPAIR_HINT=Check access to github.com, free disk space, and setup.log; then retry with a fresh official ZIP."
    goto Failed
)
:FfmpegReady
call :TouchSetupLock
if errorlevel 1 (
    set "FAIL_MESSAGE=Setup lost ownership of its private setup lock."
    goto Failed
)
echo      Done.

echo.
echo      Installing or repairing the local Deno runtime...
echo.
call :ValidateDeno
if not errorlevel 1 (
    echo      Current local copy is valid. Keeping it.
    set "LOG_MESSAGE=Existing Deno passed validation."
    call :LogCurrent
    goto DenoReady
)
echo      Downloading the verified local YouTube runtime...
call :InstallDeno
if errorlevel 1 (
    set "FAIL_MESSAGE=Deno could not be installed and verified."
    set "REPAIR_HINT=Check access to github.com, free disk space, and setup.log; then retry with a fresh official ZIP."
    goto Failed
)
:DenoReady
call :TouchSetupLock
if errorlevel 1 (
    set "FAIL_MESSAGE=Setup lost ownership of its private setup lock."
    goto Failed
)
echo      Done.

echo.
echo   [ STEP 3 / 3 ]   Final checks
echo.
echo      Testing every required component without downloading media...
call :TouchSetupLock
if errorlevel 1 (
    set "FAIL_MESSAGE=Setup lost ownership of its private setup lock."
    goto Failed
)
call :VerifyEverything
if errorlevel 1 (
    set "FAIL_MESSAGE=One or more final component checks failed."
    set "REPAIR_HINT=Read the last error in setup.log, then rerun Installer.bat to repair the specific component."
    goto Failed
)
echo      Creating the Video + Audio Downloader start shortcut...
call :CreateShortcut
if errorlevel 1 (
    set "FAIL_MESSAGE=The start shortcut could not be created."
    set "REPAIR_HINT=Close the app and any open shortcut properties window, check folder write access, then retry."
    goto Failed
)
call :WriteSetupMarker
if errorlevel 1 (
    set "FAIL_MESSAGE=Setup finished its checks but could not save the completion marker."
    goto Failed
)
echo      Every check passed.

if exist "%DOWNLOADS%" call :RemoveDirectoryRobust "%DOWNLOADS%"
if exist "%DOWNLOADS%" (
    set "FAIL_MESSAGE=Setup passed its checks but could not safely remove temporary downloads."
    goto Failed
)
set "LOG_MESSAGE=Setup completed successfully."
call :LogCurrent
call :ReleaseSetupLock

echo.
echo  ==================================================
echo                ALL SET, YOU ARE READY
echo  ==================================================
echo.
echo   Double click the "Video + Audio Downloader" shortcut in this
echo   folder to start. You can copy the shortcut to your
echo   Desktop or pin it to the taskbar.
echo.
echo   Run this installer again whenever you want to
echo   repair the app's private local files or refresh the shortcut.
echo.
echo   Setup details were saved to:
echo   "%LOG%"
echo.
call :PauseIfNeeded
exit /b 0

:SetupAlreadyRunning
echo.
echo  ==================================================
echo                 SETUP ALREADY RUNNING
echo  ==================================================
echo.
echo   Another Video + Audio Downloader setup is already running.
echo   Let that window finish, then try again.
echo.
call :PauseIfNeeded
exit /b 1

:Cancelled
call :ReleaseSetupLock
echo.
echo  ==================================================
echo                     SETUP CANCELLED
echo  ==================================================
echo.
echo   Nothing was installed or changed after cancellation.
echo   Run Installer.bat again whenever you are ready.
echo.
call :PauseIfNeeded
exit /b 1

:Failed
if not defined FAIL_MESSAGE set "FAIL_MESSAGE=Setup stopped because an unexpected error occurred."
set "LOG_MESSAGE=ERROR: %FAIL_MESSAGE%"
if defined LOG_READY call :LogCurrent
if defined PATHS_VALIDATED call :ReleaseSetupLock
echo.
echo  ==================================================
echo                     SETUP STOPPED
echo  ==================================================
echo.
echo   %FAIL_MESSAGE%
echo.
if defined REPAIR_HINT (
    echo   How to fix:
    echo   %REPAIR_HINT%
    echo.
)
echo   No success was reported because all checks did not pass.
if defined LOG_READY (
    echo   The detailed log is here:
    echo.
    echo   "%LOG%"
) else (
    echo   No new log was written because setup stopped before it could safely own one.
)
echo.
echo   Fix the listed problem, then run Installer.bat again.
echo.
call :PauseIfNeeded
exit /b 1


:AcquireSetupLock
2>nul mkdir "%SETUP_LOCK%"
if not errorlevel 1 goto SetupLockCreated
call :ValidatePrivateTree "%SETUP_LOCK%"
if errorlevel 1 exit /b 1
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $lock=$env:SETUP_LOCK; $owner=$env:SETUP_LOCK_OWNER; $max=[double]$env:SETUP_LOCK_MAX_AGE_MINUTES; $fresh=(((Get-Date)-(Get-Item -LiteralPath $lock).CreationTime).TotalSeconds -lt 30); if($fresh){exit 2}; $owned=$false; $token=$null; if(Test-Path -LiteralPath $owner){try{$data=Get-Content -LiteralPath $owner -Raw -Encoding UTF8|ConvertFrom-Json; $token=[string]$data.token; $heartbeat=[DateTime]::Parse([string]$data.heartbeatUtc).ToUniversalTime(); $process=Get-CimInstance Win32_Process -Filter ('ProcessId=' + [int]$data.pid) -ErrorAction SilentlyContinue; if($process -and $process.Name -ieq 'cmd.exe'){$started=([DateTime]$process.CreationDate).ToUniversalTime(); $recorded=[DateTime]::Parse([string]$data.processStartedUtc).ToUniversalTime(); $sameProcess=[Math]::Abs(($started-$recorded).TotalSeconds) -lt 3; $dedicatedChild=($data.child -eq $true -and [string]$process.CommandLine -match '(?i)--fleece-setup-child(?:\s|$)'); if($sameProcess -and ($dedicatedChild -or ([DateTime]::UtcNow-$heartbeat).TotalMinutes -lt $max)){$owned=$true}}}catch{}}; if($owned){exit 2}; if(Test-Path -LiteralPath $owner){try{$latest=Get-Content -LiteralPath $owner -Raw -Encoding UTF8|ConvertFrom-Json; if($token -and [string]$latest.token -ne $token){exit 2}}catch{if($token){exit 2}}}; $stale=$lock+'.stale-'+[Guid]::NewGuid().ToString('N'); Move-Item -LiteralPath $lock -Destination $stale; Remove-Item -LiteralPath $stale -Recurse -Force" >nul 2>nul
if errorlevel 1 exit /b 1
2>nul mkdir "%SETUP_LOCK%"
if errorlevel 1 exit /b 1

:SetupLockCreated
set "SETUP_LOCK_HELD=1"
set "SETUP_LOCK_TOKEN_FILE=%SETUP_LOCK%\token.txt"
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -Command "[Guid]::NewGuid().ToString('N')" >"%SETUP_LOCK_TOKEN_FILE%" 2>nul
if exist "%SETUP_LOCK_TOKEN_FILE%" set /p "SETUP_LOCK_TOKEN="<"%SETUP_LOCK_TOKEN_FILE%"
del /f /q "%SETUP_LOCK_TOKEN_FILE%" >nul 2>nul
if not defined SETUP_LOCK_TOKEN goto SetupLockCreateFailed
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $self=Get-CimInstance Win32_Process -Filter ('ProcessId=' + $PID); if(-not $self -or -not $self.ParentProcessId){throw 'Could not identify the setup process.'}; $parent=Get-CimInstance Win32_Process -Filter ('ProcessId=' + $self.ParentProcessId); if(-not $parent){throw 'Could not identify the setup process.'}; if($env:SETUP_CHILD -ne '1' -or [string]$parent.CommandLine -notmatch '(?i)--fleece-setup-child(?:\s|$)'){throw 'Could not verify the dedicated setup child.'}; $started=([DateTime]$parent.CreationDate).ToUniversalTime().ToString('o'); $data=[ordered]@{schema=2;pid=[int]$parent.ProcessId;processStartedUtc=$started;token=$env:SETUP_LOCK_TOKEN;heartbeatUtc=[DateTime]::UtcNow.ToString('o');child=$true}; $new=$env:SETUP_LOCK_OWNER+'.new'; $data|ConvertTo-Json -Compress|Set-Content -LiteralPath $new -Encoding UTF8; Move-Item -LiteralPath $new -Destination $env:SETUP_LOCK_OWNER -Force" >nul 2>nul
if not errorlevel 1 exit /b 0

:SetupLockCreateFailed
del /f /q "%SETUP_LOCK_OWNER%" >nul 2>nul
rmdir "%SETUP_LOCK%" >nul 2>nul
set "SETUP_LOCK_HELD=0"
set "SETUP_LOCK_TOKEN="
exit /b 1

:EnsureAppClosed
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "foreach($name in @('Global\FleeceVideoDownloaderApp','Local\FleeceVideoDownloaderApp')){try{$mutex=[Threading.Mutex]::OpenExisting($name);$mutex.Dispose();exit 1}catch [Threading.WaitHandleCannotBeOpenedException]{}catch{exit 1}};exit 0" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:CheckBundledSource
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$item=Get-Item -LiteralPath $env:APP_FILE -Force;if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -lt 1 -or $item.Length -gt 4MB){throw 'Bundled app source is not a normal bounded file.'};$text=[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($item.FullName));if([string]::IsNullOrWhiteSpace($text)){throw 'Bundled app source is empty.'};Write-Output 'Bundled app source passed preflight.'" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:CheckArchiveSupport
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$cmd=Get-Command Expand-Archive -ErrorAction Stop;if($cmd.CommandType -ne 'Function' -and $cmd.CommandType -ne 'Cmdlet'){throw 'Expand-Archive is unavailable.'};$probe=Join-Path $env:RUNTIME ('archive-preflight-'+[Guid]::NewGuid().ToString('N'));$archive=$probe+'.zip';$source=$probe+'.txt';$out=$probe+'.out';try{[IO.File]::WriteAllText($source,'ok');Compress-Archive -LiteralPath $source -DestinationPath $archive -ErrorAction Stop;Expand-Archive -LiteralPath $archive -DestinationPath $out -ErrorAction Stop;if(-not(Test-Path -LiteralPath (Join-Path $out ([IO.Path]::GetFileName($source))) -PathType Leaf)){throw 'Windows could not extract a test ZIP.'}}finally{foreach($file in @($source,$archive)){if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force}};if(Test-Path -LiteralPath $out){Remove-Item -LiteralPath $out -Recurse -Force}};Write-Output 'Windows ZIP extraction passed preflight.'" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:CheckShortcutSupport
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';foreach($name in @('Video + Audio Downloader.lnk','Video Downloader.lnk')){$path=Join-Path $env:ROOT $name;if(Test-Path -LiteralPath $path){$item=Get-Item -LiteralPath $path -Force;if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw ('The existing shortcut path is unsafe: '+$name)}}};$shell=New-Object -ComObject WScript.Shell;$probe=Join-Path $env:RUNTIME ('shortcut-preflight-'+[Guid]::NewGuid().ToString('N')+'.lnk');try{$link=$shell.CreateShortcut($probe);$link.TargetPath=$env:POWERSHELL_EXE;$link.WorkingDirectory=$env:RUNTIME;$link.Save();if(-not(Test-Path -LiteralPath $probe -PathType Leaf)){throw 'Windows did not save a test shortcut.'};$readback=$shell.CreateShortcut($probe);if([IO.Path]::GetFullPath($readback.TargetPath) -ine [IO.Path]::GetFullPath($env:POWERSHELL_EXE)){throw 'Windows did not preserve the shortcut target.'}}finally{if(Test-Path -LiteralPath $probe){Remove-Item -LiteralPath $probe -Force}};Write-Output 'Windows shortcut creation and readback passed preflight.'" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:CheckRootWritePermission
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$root=[IO.Path]::GetFullPath($env:ROOT).TrimEnd('\');$probe=Join-Path $root ('.fleece-write-test-'+[Guid]::NewGuid().ToString('N')+'.tmp');try{$stream=[IO.File]::Open($probe,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$stream.Dispose()}finally{if(Test-Path -LiteralPath $probe){Remove-Item -LiteralPath $probe -Force}};exit 0" >nul 2>nul
exit /b %ERRORLEVEL%

:ValidatePrivatePaths
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$root=[IO.Path]::GetFullPath($env:ROOT).TrimEnd('\');$volume=[IO.Path]::GetPathRoot($root).TrimEnd('\');if([string]::IsNullOrWhiteSpace($root)-or $root -ieq $volume){throw 'Unsafe project root.'};$rootItem=Get-Item -LiteralPath $root -Force;if(-not $rootItem.PSIsContainer-or($rootItem.Attributes-band[IO.FileAttributes]::ReparsePoint)){throw 'The project root must be a normal directory.'};$targets=@($env:RUNTIME,$env:VENV,$env:DOWNLOADS,$env:PYTHON_DIR,(Join-Path $env:PYTHON_DIR 'Lib'),$env:LOCAL_SITE,$env:SETUP_LOCK,($env:PYTHON_DIR+'.new'),($env:PYTHON_DIR+'.old'),($env:VENV+'.old'),(Join-Path $env:RUNTIME 'b'),(Join-Path $env:RUNTIME 'b.new'),(Join-Path $env:RUNTIME 'b.old'),(Join-Path $env:RUNTIME 'setup-check'));foreach($name in @('FFMPEG_DIR','DENO_DIR','HERCULES_DIR','LUA_DIR')){$value=[Environment]::GetEnvironmentVariable($name);if($value){$targets+=@($value,($value+'.new'),($value+'.old'),($value+'.extract'))}};$prefix=$root+'\';foreach($target in $targets){if([string]::IsNullOrWhiteSpace($target)){throw 'A private setup path is empty.'};$full=[IO.Path]::GetFullPath($target).TrimEnd('\');if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'A private setup path escaped the project root.'};if(Test-Path -LiteralPath $full){$item=Get-Item -LiteralPath $full -Force;if(-not $item.PSIsContainer-or($item.Attributes-band[IO.FileAttributes]::ReparsePoint)){throw 'A private setup directory is unsafe.'}}};foreach($file in @($env:LOG,$env:SETUP_MARKER,($env:SETUP_MARKER+'.new'),$env:SETUP_LOCK_OWNER,($env:SETUP_LOCK_OWNER+'.new'),$env:PIP_WHEEL)){if([string]::IsNullOrWhiteSpace($file)){continue};$full=[IO.Path]::GetFullPath($file);if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'A private setup file escaped the project root.'};if(Test-Path -LiteralPath $full){$item=Get-Item -LiteralPath $full -Force;if($item.PSIsContainer-or($item.Attributes-band[IO.FileAttributes]::ReparsePoint)){throw 'A private setup file is unsafe.'}}};exit 0" >nul 2>nul
exit /b %ERRORLEVEL%

:WriteSetupMarker
if /I not "%ENV_MODE%"=="embedded" exit /b 1
>"%SETUP_MARKER%.new" echo %ENV_MODE%
if errorlevel 1 exit /b 1
move /y "%SETUP_MARKER%.new" "%SETUP_MARKER%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
if not exist "%SETUP_MARKER%" exit /b 1
exit /b 0

:ReleaseSetupLock
if not "%SETUP_LOCK_HELD%"=="1" exit /b 0
call :ValidatePrivateTree "%SETUP_LOCK%"
if errorlevel 1 exit /b 2
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; if(-not(Test-Path -LiteralPath $env:SETUP_LOCK_OWNER)){exit 2}; $data=Get-Content -LiteralPath $env:SETUP_LOCK_OWNER -Raw -Encoding UTF8|ConvertFrom-Json; if([string]$data.token -ne $env:SETUP_LOCK_TOKEN){exit 2}; $released=$env:SETUP_LOCK+'.released-'+[Guid]::NewGuid().ToString('N'); Move-Item -LiteralPath $env:SETUP_LOCK -Destination $released; Remove-Item -LiteralPath $released -Recurse -Force" >nul 2>nul
set "RELEASE_LOCK_CODE=%ERRORLEVEL%"
set "SETUP_LOCK_HELD=0"
set "SETUP_LOCK_TOKEN="
exit /b %RELEASE_LOCK_CODE%

:TouchSetupLock
if not "%SETUP_LOCK_HELD%"=="1" exit /b 0
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $data=Get-Content -LiteralPath $env:SETUP_LOCK_OWNER -Raw -Encoding UTF8|ConvertFrom-Json; if([string]$data.token -ne $env:SETUP_LOCK_TOKEN){exit 2}; $data.heartbeatUtc=[DateTime]::UtcNow.ToString('o'); $new=$env:SETUP_LOCK_OWNER+'.new'; $data|ConvertTo-Json -Compress|Set-Content -LiteralPath $new -Encoding UTF8; Move-Item -LiteralPath $new -Destination $env:SETUP_LOCK_OWNER -Force" >nul 2>nul
exit /b %ERRORLEVEL%


:ValidateEmbeddedPython
call :ValidateEmbeddedPythonAt "%PYTHON_DIR%"
exit /b %ERRORLEVEL%

:ValidateEmbeddedPythonAt
if "%~1"=="" exit /b 1
if not exist "%~1\python.exe" exit /b 1
if not exist "%~1\pythonw.exe" exit /b 1
if not exist "%~1\Lib\site-packages" exit /b 1
if not exist "%~1\pip.whl" exit /b 1
call :VerifyFileHash "%~1\pip.whl" "%PIP_WHEEL_SHA256%"
if errorlevel 1 exit /b 1
"%~1\python.exe" -I -c "import sys, struct, site; ok = sys.implementation.name == 'cpython' and sys.version_info[:3] == (3, 14, 7) and struct.calcsize('P') == 8 and any(p.lower().endswith(r'lib\site-packages') for p in sys.path); raise SystemExit(0 if ok else 1)" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
"%~1\python.exe" -I -c "import sys; sys.path.insert(0, sys.argv[1]); from pip._internal.cli.main import main; raise SystemExit(main(sys.argv[2:]))" "%~1\pip.whl" --version >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:InstallEmbedPy
call :ValidateEmbeddedPython
if not errorlevel 1 exit /b 0

set "PYTHON_ARCHIVE=%DOWNLOADS%\python-%PYTHON_VERSION%-embed-%ARCH%.zip"
set "PYTHON_NEW=%RUNTIME%\python.new"
set "PIP_DOWNLOAD=%DOWNLOADS%\pip.whl"
call :DownloadAndVerify "%PYTHON_URL%" "%PYTHON_ARCHIVE%" "%PYTHON_SHA256%"
if errorlevel 1 exit /b 1
call :DownloadAndVerify "%PIP_WHEEL_URL%" "%PIP_DOWNLOAD%" "%PIP_WHEEL_SHA256%"
if errorlevel 1 exit /b 1

if exist "%PYTHON_NEW%" call :RemoveDirectoryRobust "%PYTHON_NEW%"
if exist "%PYTHON_NEW%" exit /b 1
set "ARCHIVE_FILE=%PYTHON_ARCHIVE%"
set "NEW_DIR=%PYTHON_NEW%"
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_FILE -DestinationPath $env:NEW_DIR -Force; $pth=Get-ChildItem -LiteralPath $env:NEW_DIR -Filter 'python*._pth' -File | Select-Object -First 1; if(-not $pth){throw 'Python archive did not contain its path configuration.'}; $lines=@(Get-Content -LiteralPath $pth.FullName | Where-Object { $_ -notmatch '^\s*#?\s*import site\s*$' -and $_ -notmatch '^\s*Lib\\site-packages\s*$' }); $lines += 'Lib\site-packages'; $lines += 'import site'; Set-Content -LiteralPath $pth.FullName -Value $lines -Encoding ASCII; New-Item -ItemType Directory -Path (Join-Path $env:NEW_DIR 'Lib\site-packages') -Force | Out-Null; Copy-Item -LiteralPath $env:PIP_DOWNLOAD -Destination (Join-Path $env:NEW_DIR 'pip.whl') -Force" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

call :ValidateEmbeddedPythonAt "%PYTHON_NEW%"
set "TEMP_VALIDATE_CODE=%ERRORLEVEL%"
if not "%TEMP_VALIDATE_CODE%"=="0" exit /b 1

call :ReplaceDirectory "%PYTHON_NEW%" "%PYTHON_DIR%"
if errorlevel 1 exit /b 1
del /f /q "%PYTHON_ARCHIVE%" "%PIP_DOWNLOAD%" >nul 2>nul
call :ValidateEmbeddedPython
if errorlevel 1 exit /b 1
set "LOG_MESSAGE=Official embedded CPython passed local validation."
call :LogCurrent
exit /b 0

:ValidateSelectedEnvironment
if /I not "%ENV_MODE%"=="embedded" exit /b 1
call :ValidateEmbeddedPython
exit /b %ERRORLEVEL%

:ValidateLegacyVenvLayoutAt
if "%~1"=="" exit /b 1
if not exist "%~1\Scripts\python.exe" exit /b 1
if not exist "%~1\Scripts\pythonw.exe" exit /b 1
if not exist "%~1\pyvenv.cfg" exit /b 1
exit /b 0

:InstallPythonPackages
if not defined APP_PY exit /b 1
if not exist "%APP_PY%" exit /b 1
call :ValidatePipRequirements
if errorlevel 1 exit /b 1
call :CurrentPackagesFullyHealthy
if not errorlevel 1 exit /b 0
call :BeginPackageTransaction
if errorlevel 1 exit /b 1
if /I not "%ENV_MODE%"=="embedded" exit /b 1
call :InstallEmbeddedPackages
set "PACKAGE_TRANSACTION_CODE=%ERRORLEVEL%"
call :FinishPackageTransaction %PACKAGE_TRANSACTION_CODE%
exit /b %ERRORLEVEL%

:CurrentPackagesFullyHealthy
call :HasPinnedPySide
if errorlevel 1 exit /b 1
call :HasPinnedDownloaderPackages
if errorlevel 1 exit /b 1
call :VerifyPythonPackages
exit /b %ERRORLEVEL%

:BeginPackageTransaction
set "PACKAGE_BACKUP=%RUNTIME%\b"
set "PACKAGE_BACKUP_NEW=%PACKAGE_BACKUP%.new"
set "PACKAGE_BACKUP_MARKER=%PACKAGE_BACKUP%.complete"
if /I not "%ENV_MODE%"=="embedded" exit /b 1
set "PACKAGE_TARGET=%PYTHON_DIR%"
set "PACKAGE_BACKUP_PROBE=python.exe"
if not exist "%PACKAGE_BACKUP%" goto PackageBackupAbsent
call :ValidatePrivateTree "%PACKAGE_BACKUP%"
if errorlevel 1 exit /b 1
if not exist "%PACKAGE_BACKUP_MARKER%" goto RemoveIncompletePackageBackup
if not exist "%PACKAGE_BACKUP%\%PACKAGE_BACKUP_PROBE%" (
    call :ValidateLegacyVenvLayoutAt "%PACKAGE_BACKUP%"
    if not errorlevel 1 goto RemoveIncompletePackageBackup
    exit /b 1
)
set "LOG_MESSAGE=Recovering the local package environment left by an interrupted repair."
call :LogCurrent
call :RemoveDirectoryRobust "%PACKAGE_TARGET%"
if errorlevel 1 exit /b 1
move "%PACKAGE_BACKUP%" "%PACKAGE_TARGET%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
del /f /q "%PACKAGE_BACKUP_MARKER%" >nul 2>nul
goto PackageBackupAbsent

:RemoveIncompletePackageBackup
call :RemoveDirectoryRobust "%PACKAGE_BACKUP%"
if errorlevel 1 exit /b 1

:PackageBackupAbsent
if exist "%PACKAGE_BACKUP_MARKER%" del /f /q "%PACKAGE_BACKUP_MARKER%" >nul 2>nul
if exist "%PACKAGE_BACKUP_NEW%" call :RemoveDirectoryRobust "%PACKAGE_BACKUP_NEW%"
if exist "%PACKAGE_BACKUP_NEW%" exit /b 1
if not exist "%PACKAGE_TARGET%" exit /b 1
call :ValidatePrivateTree "%PACKAGE_TARGET%"
if errorlevel 1 exit /b 1
set "LOG_MESSAGE=Creating a local rollback copy before package repair."
call :LogCurrent
"%ROBOCOPY_EXE%" "%PACKAGE_TARGET%" "%PACKAGE_BACKUP_NEW%" /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XJ /NFL /NDL /NJH /NJS /NP >>"%LOG%" 2>&1
if errorlevel 8 exit /b 1
call :ValidatePrivateTree "%PACKAGE_BACKUP_NEW%"
if errorlevel 1 exit /b 1
if not exist "%PACKAGE_BACKUP_NEW%\%PACKAGE_BACKUP_PROBE%" exit /b 1
move "%PACKAGE_BACKUP_NEW%" "%PACKAGE_BACKUP%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
>"%PACKAGE_BACKUP_MARKER%" echo complete
if not exist "%PACKAGE_BACKUP%" exit /b 1
if not exist "%PACKAGE_BACKUP_MARKER%" exit /b 1
call :ValidatePrivateTree "%PACKAGE_BACKUP%"
if errorlevel 1 exit /b 1
exit /b 0

:FinishPackageTransaction
set "PACKAGE_TRANSACTION_CODE=%~1"
if "%PACKAGE_TRANSACTION_CODE%"=="0" (
    if exist "%PACKAGE_BACKUP%" call :RemoveDirectoryRobust "%PACKAGE_BACKUP%"
    if exist "%PACKAGE_BACKUP%" exit /b 1
    if exist "%PACKAGE_BACKUP_MARKER%" del /f /q "%PACKAGE_BACKUP_MARKER%" >nul 2>nul
    if exist "%PACKAGE_BACKUP_MARKER%" exit /b 1
    exit /b 0
)
set "LOG_MESSAGE=Package repair failed; restoring the previous private Python environment."
call :LogCurrent
call :RemoveDirectoryRobust "%PACKAGE_TARGET%"
if errorlevel 1 exit /b 1
move "%PACKAGE_BACKUP%" "%PACKAGE_TARGET%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
if exist "%PACKAGE_BACKUP_MARKER%" del /f /q "%PACKAGE_BACKUP_MARKER%" >nul 2>nul
exit /b %PACKAGE_TRANSACTION_CODE%

:ValidatePipRequirements
set "PIP_REQUIREMENTS_SHA256="
if /I "%ARCH%"=="x64" set "PIP_REQUIREMENTS_SHA256=e91234bb8eb9dbe6555a9a03101500e065488834e1d40939630c99acfb415f20"
if /I "%ARCH%"=="arm64" set "PIP_REQUIREMENTS_SHA256=9dd5fa00bc1f5192291ab0281c75a975284ba141222f7dee51af5249606625cd"
if not defined PIP_REQUIREMENTS_SHA256 exit /b 1
"%APP_PY%" -I -c "import hashlib, os, stat; from pathlib import Path; path=Path(os.environ['PIP_REQUIREMENTS']); info=path.stat(follow_symlinks=False); assert stat.S_ISREG(info.st_mode) and not path.is_symlink() and not (getattr(info, 'st_file_attributes', 0) & 1024), 'Dependency lock is unsafe'; assert hashlib.sha256(path.read_bytes()).hexdigest() == os.environ['PIP_REQUIREMENTS_SHA256'], 'Dependency lock SHA-256 mismatch'" >>"%LOG%" 2>&1
if not errorlevel 1 exit /b 0
set "LOG_MESSAGE=The reviewed dependency lock is missing, unsafe, or changed. Re-extract the complete official ZIP."
call :LogCurrent
exit /b 1

:InstallEmbeddedPackages
call :ValidateEmbeddedPython
if errorlevel 1 exit /b 1
call :ValidatePipRequirements
if errorlevel 1 exit /b 1
call :HasPinnedPySide
if errorlevel 1 goto InstallFullEmbeddedPackages
call :VerifyPythonPackages
if not errorlevel 1 exit /b 0

:InstallFullEmbeddedPackages
set "LOG_MESSAGE=Installing pinned app packages into embedded CPython from official PyPI."
call :LogCurrent
call :RemoveDirectoryRobust "%LOCAL_SITE%"
if errorlevel 1 exit /b 1
mkdir "%LOCAL_SITE%" >>"%LOG%" 2>&1
if not exist "%LOCAL_SITE%" exit /b 1
"%APP_PY%" -I -c "import sys; sys.path.insert(0, sys.argv[1]); from pip._internal.cli.main import main; raise SystemExit(main(sys.argv[2:]))" "%PIP_WHEEL%" --isolated --disable-pip-version-check install --upgrade --no-cache-dir --only-binary=:all: --require-hashes --index-url "%PYPI_INDEX%" --target "%LOCAL_SITE%" -r "%PIP_REQUIREMENTS%" >>"%LOG%" 2>&1
set "PACKAGE_INSTALL_CODE=%ERRORLEVEL%"

if not "%PACKAGE_INSTALL_CODE%"=="0" goto RepairPythonPackages
call :VerifyPythonPackages
if not errorlevel 1 exit /b 0

:RepairPythonPackages
echo      A component check failed. Repairing local packages...
set "LOG_MESSAGE=Initial package validation failed; forcing a clean package reinstall."
call :LogCurrent
if /I not "%ENV_MODE%"=="embedded" exit /b 1

call :RemoveDirectoryRobust "%LOCAL_SITE%"
if errorlevel 1 exit /b 1
mkdir "%LOCAL_SITE%" >>"%LOG%" 2>&1
if not exist "%LOCAL_SITE%" exit /b 1
"%APP_PY%" -I -c "import sys; sys.path.insert(0, sys.argv[1]); from pip._internal.cli.main import main; raise SystemExit(main(sys.argv[2:]))" "%PIP_WHEEL%" --isolated --disable-pip-version-check install --upgrade --force-reinstall --no-cache-dir --only-binary=:all: --require-hashes --index-url "%PYPI_INDEX%" --target "%LOCAL_SITE%" -r "%PIP_REQUIREMENTS%" >>"%LOG%" 2>&1

if errorlevel 1 exit /b 1
call :VerifyPythonPackages
exit /b %ERRORLEVEL%

:VerifyPythonPackages
if not defined APP_PY exit /b 1
if not exist "%APP_PY%" exit /b 1
"%APP_PY%" -I -c "import PySide6, yt_dlp, certifi, charset_normalizer, idna, mutagen, Cryptodome, requests, urllib3, websockets; from importlib.metadata import version; from PySide6.QtCore import qVersion; expected={'%PYSIDE_DISTRIBUTION%':'%PYSIDE_VERSION%','yt-dlp':'%YTDLP_VERSION%','yt-dlp-ejs':'%YTDLP_EJS_VERSION%','certifi':'%CERTIFI_VERSION%','charset-normalizer':'%CHARSET_NORMALIZER_VERSION%','idna':'%IDNA_VERSION%','mutagen':'%MUTAGEN_VERSION%','pycryptodomex':'%PYCRYPTODOMEX_VERSION%','requests':'%REQUESTS_VERSION%','urllib3':'%URLLIB3_VERSION%','websockets':'%WEBSOCKETS_VERSION%'}; assert all(version(name) == wanted for name, wanted in expected.items()); print('%PYSIDE_DISTRIBUTION%=' + version('%PYSIDE_DISTRIBUTION%')); print('Qt=' + qVersion()); print('yt-dlp=' + version('yt-dlp')); print('yt-dlp-ejs=' + version('yt-dlp-ejs'))" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
call :VerifyEjsAssets
if errorlevel 1 exit /b 1
if /I "%ARCH%"=="x64" (
    "%APP_PY%" -I -c "import brotli; from importlib.metadata import version; raise SystemExit(0 if version('Brotli') == '%BROTLI_VERSION%' else 1)" >>"%LOG%" 2>&1
    if errorlevel 1 exit /b 1
)
if /I not "%ENV_MODE%"=="embedded" exit /b 1
"%APP_PY%" -I -c "import sys; sys.path.insert(0, sys.argv[1]); from pip._internal.cli.main import main; raise SystemExit(main(sys.argv[2:]))" "%PIP_WHEEL%" --isolated --disable-pip-version-check check >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
"%APP_PY%" -I -m yt_dlp --ignore-config --version >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:HasPinnedPySide
if not defined APP_PY exit /b 1
if not exist "%APP_PY%" exit /b 1
"%APP_PY%" -I -c "import PySide6; from importlib.metadata import version; raise SystemExit(0 if version('%PYSIDE_DISTRIBUTION%') == '%PYSIDE_VERSION%' else 1)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:HasPinnedDownloaderPackages
if not defined APP_PY exit /b 1
if not exist "%APP_PY%" exit /b 1
"%APP_PY%" -I -c "from importlib.metadata import version; expected={'yt-dlp':'%YTDLP_VERSION%','yt-dlp-ejs':'%YTDLP_EJS_VERSION%','certifi':'%CERTIFI_VERSION%','charset-normalizer':'%CHARSET_NORMALIZER_VERSION%','idna':'%IDNA_VERSION%','mutagen':'%MUTAGEN_VERSION%','pycryptodomex':'%PYCRYPTODOMEX_VERSION%','requests':'%REQUESTS_VERSION%','urllib3':'%URLLIB3_VERSION%','websockets':'%WEBSOCKETS_VERSION%'}; raise SystemExit(0 if all(version(name) == wanted for name, wanted in expected.items()) else 1)" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
if /I "%ARCH%"=="x64" "%APP_PY%" -I -c "from importlib.metadata import version; raise SystemExit(0 if version('Brotli') == '%BROTLI_VERSION%' else 1)" >>"%LOG%" 2>&1
exit /b %ERRORLEVEL%

:VerifyEjsAssets
if not defined APP_PY exit /b 1
if not exist "%APP_PY%" exit /b 1
"%APP_PY%" -I -c "import hashlib, stat, yt_dlp_ejs; from pathlib import Path; root=Path(yt_dlp_ejs.__file__).resolve(strict=True).parent; expected={Path('yt/solver/core.min.js'):'%YTDLP_EJS_CORE_SHA256%',Path('yt/solver/lib.min.js'):'%YTDLP_EJS_LIB_SHA256%'}; assets=[(root/relative,wanted) for relative,wanted in expected.items()]; assert all(stat.S_ISREG(path.stat(follow_symlinks=False).st_mode) and not path.is_symlink() and hashlib.sha256(path.read_bytes()).hexdigest().upper() == wanted for path,wanted in assets)" >>"%LOG%" 2>&1
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
call :TouchSetupLock
if errorlevel 1 exit /b 1
if exist "%FFMPEG_EXTRACT%" call :RemoveDirectoryRobust "%FFMPEG_EXTRACT%"
if exist "%FFMPEG_EXTRACT%" exit /b 1
if exist "%FFMPEG_NEW%" call :RemoveDirectoryRobust "%FFMPEG_NEW%"
if exist "%FFMPEG_NEW%" exit /b 1
set "ARCHIVE_FILE=%FFMPEG_ARCHIVE%"
set "EXTRACT_DIR=%FFMPEG_EXTRACT%"
set "NEW_DIR=%FFMPEG_NEW%"
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_FILE -DestinationPath $env:EXTRACT_DIR -Force; $ff=Get-ChildItem -LiteralPath $env:EXTRACT_DIR -Filter ffmpeg.exe -File -Recurse | Select-Object -First 1; $fp=Get-ChildItem -LiteralPath $env:EXTRACT_DIR -Filter ffprobe.exe -File -Recurse | Select-Object -First 1; if(-not $ff -or -not $fp){throw 'FFmpeg archive did not contain both required programs.'}; New-Item -ItemType Directory -Path $env:NEW_DIR -Force | Out-Null; Copy-Item -LiteralPath $ff.FullName -Destination (Join-Path $env:NEW_DIR 'ffmpeg.exe') -Force; Copy-Item -LiteralPath $fp.FullName -Destination (Join-Path $env:NEW_DIR 'ffprobe.exe') -Force" >>"%LOG%" 2>&1
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
if exist "%FFMPEG_EXTRACT%" call :RemoveDirectoryRobust "%FFMPEG_EXTRACT%"
if exist "%FFMPEG_EXTRACT%" exit /b 1
del /f /q "%FFMPEG_ARCHIVE%" >nul 2>nul
call :TouchSetupLock
if errorlevel 1 exit /b 1
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
call :TouchSetupLock
if errorlevel 1 exit /b 1
if exist "%DENO_NEW%" call :RemoveDirectoryRobust "%DENO_NEW%"
if exist "%DENO_NEW%" exit /b 1
set "ARCHIVE_FILE=%DENO_ARCHIVE%"
set "NEW_DIR=%DENO_NEW%"
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:ARCHIVE_FILE -DestinationPath $env:NEW_DIR -Force; if(-not (Test-Path -LiteralPath (Join-Path $env:NEW_DIR 'deno.exe'))){throw 'Deno archive did not contain deno.exe.'}" >>"%LOG%" 2>&1
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
call :TouchSetupLock
if errorlevel 1 exit /b 1
call :ValidateDeno
exit /b %ERRORLEVEL%

:RemoveDirectoryRobust
set "REMOVE_TREE=%~1"
if not defined REMOVE_TREE exit /b 1
if not exist "%REMOVE_TREE%" exit /b 0
call :ValidatePrivateTree "%REMOVE_TREE%"
if errorlevel 1 exit /b 1
set "EMPTY_TREE=%RUNTIME%\empty-%RANDOM%-%RANDOM%"
if exist "%EMPTY_TREE%" exit /b 1
mkdir "%EMPTY_TREE%" >>"%LOG%" 2>&1
if not exist "%EMPTY_TREE%" exit /b 1
call :ValidatePrivateTree "%EMPTY_TREE%"
if errorlevel 1 exit /b 1
"%ROBOCOPY_EXE%" "%EMPTY_TREE%" "%REMOVE_TREE%" /MIR /R:2 /W:1 /XJ /NFL /NDL /NJH /NJS /NP /NC /NS >nul 2>>"%LOG%"
if errorlevel 8 exit /b 1
rmdir /s /q "%REMOVE_TREE%" >>"%LOG%" 2>&1
rmdir /s /q "%EMPTY_TREE%" >>"%LOG%" 2>&1
if exist "%REMOVE_TREE%" exit /b 1
if exist "%EMPTY_TREE%" exit /b 1
exit /b 0

:ValidatePrivateTree
if "%~1"=="" exit /b 1
set "VALIDATE_TREE=%~1"
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$project=[IO.Path]::GetFullPath($env:ROOT).TrimEnd('\');$root=[IO.Path]::GetFullPath($env:VALIDATE_TREE).TrimEnd('\');if(-not $root.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Private tree escaped the project root.'};$extended=if($root.StartsWith('\\')){'\\?\UNC\'+$root.Substring(2)}else{'\\?\'+$root};$stack=New-Object 'System.Collections.Generic.Stack[string]';$stack.Push($extended);while($stack.Count -gt 0){$directory=$stack.Pop();$attributes=[IO.File]::GetAttributes($directory);if(-not($attributes-band[IO.FileAttributes]::Directory)-or($attributes-band[IO.FileAttributes]::ReparsePoint)){throw 'Unsafe private directory.'};foreach($entryPath in [IO.Directory]::EnumerateFileSystemEntries($directory)){$entryAttributes=[IO.File]::GetAttributes($entryPath);if($entryAttributes-band[IO.FileAttributes]::ReparsePoint){throw 'Unsafe private reparse point.'};if($entryAttributes-band[IO.FileAttributes]::Directory){$stack.Push($entryPath)}}};exit 0" >>"%DIAGNOSTIC_LOG%" 2>&1
exit /b %ERRORLEVEL%

:ReplaceDirectory
set "REPLACE_NEW=%~1"
set "REPLACE_TARGET=%~2"
goto ReplaceDirectoryValuesReady

:ReplaceDirectoryValuesReady
set "REPLACE_BACKUP=%REPLACE_TARGET%.old"
if not exist "%REPLACE_NEW%" exit /b 1
call :ValidatePrivateTree "%REPLACE_NEW%"
if errorlevel 1 exit /b 1
if exist "%REPLACE_TARGET%" (
    call :ValidatePrivateTree "%REPLACE_TARGET%"
    if errorlevel 1 exit /b 1
)
if exist "%REPLACE_BACKUP%" (
    call :ValidatePrivateTree "%REPLACE_BACKUP%"
    if errorlevel 1 exit /b 1
    if exist "%REPLACE_TARGET%" (
        call :RemoveDirectoryRobust "%REPLACE_BACKUP%"
        if errorlevel 1 exit /b 1
        if exist "%REPLACE_BACKUP%" exit /b 1
    ) else (
        move "%REPLACE_BACKUP%" "%REPLACE_TARGET%" >>"%LOG%" 2>&1
        if errorlevel 1 exit /b 1
        if exist "%REPLACE_BACKUP%" exit /b 1
        call :ValidatePrivateTree "%REPLACE_TARGET%"
        if errorlevel 1 exit /b 1
    )
)
if not exist "%REPLACE_TARGET%" goto ReplaceMoveNew
move "%REPLACE_TARGET%" "%REPLACE_BACKUP%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

:ReplaceMoveNew
move "%REPLACE_NEW%" "%REPLACE_TARGET%" >>"%LOG%" 2>&1
if errorlevel 1 goto ReplaceRollback
if exist "%REPLACE_BACKUP%" (
    call :RemoveDirectoryRobust "%REPLACE_BACKUP%"
    if errorlevel 1 exit /b 1
)
if exist "%REPLACE_BACKUP%" exit /b 1
exit /b 0

:ReplaceRollback
if exist "%REPLACE_TARGET%" (
    call :RemoveDirectoryRobust "%REPLACE_TARGET%"
    if errorlevel 1 exit /b 1
)
if exist "%REPLACE_TARGET%" exit /b 1
if not exist "%REPLACE_BACKUP%" exit /b 1
call :ValidatePrivateTree "%REPLACE_BACKUP%"
if errorlevel 1 exit /b 1
move "%REPLACE_BACKUP%" "%REPLACE_TARGET%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
if exist "%REPLACE_BACKUP%" exit /b 1
if not exist "%REPLACE_TARGET%" exit /b 1
call :ValidatePrivateTree "%REPLACE_TARGET%"
if errorlevel 1 exit /b 1
exit /b 1

:DownloadAndVerify
set "DL_URL=%~1"
set "DL_FILE=%~2"
set "DL_HASH=%~3"
if not defined DL_HASH exit /b 1
if not exist "%DL_FILE%" goto DownloadFresh
call :VerifyFileHash "%DL_FILE%" "%DL_HASH%"
if not errorlevel 1 (
    set "LOG_MESSAGE=Reusing an already downloaded file that passed SHA-256 verification: %DL_FILE%"
    call :LogCurrent
    exit /b 0
)
del /f /q "%DL_FILE%" >nul 2>nul

:DownloadFresh
if exist "%DL_FILE%" del /f /q "%DL_FILE%" >nul 2>nul
set "LOG_MESSAGE=Downloading: %DL_URL%"
call :LogCurrent
call :TouchSetupLock
if errorlevel 1 exit /b 1

if not exist "%CURL_EXE%" goto DownloadWithPowerShell
"%CURL_EXE%" --fail --location --silent --show-error --retry 3 --retry-delay 2 --connect-timeout 30 --proto "=https" --proto-redir "=https" -o "%DL_FILE%" "%DL_URL%" >>"%LOG%" 2>&1
if not errorlevel 1 goto VerifyDownload
set "LOG_MESSAGE=curl failed; retrying with PowerShell."
call :LogCurrent

:DownloadWithPowerShell
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri $env:DL_URL -OutFile $env:DL_FILE" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1

:VerifyDownload
call :TouchSetupLock
if errorlevel 1 exit /b 1
if not exist "%DL_FILE%" exit /b 1
call :VerifyFileHash "%DL_FILE%" "%DL_HASH%"
exit /b %ERRORLEVEL%

:VerifyFileHash
set "VERIFY_FILE=%~1"
set "VERIFY_HASH=%~2"
if not exist "%VERIFY_FILE%" exit /b 1
if not defined VERIFY_HASH exit /b 1
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $stream=[IO.File]::OpenRead($env:VERIFY_FILE); try{$sha=[Security.Cryptography.SHA256]::Create(); try{$actual=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')} finally{$sha.Dispose()}} finally{$stream.Dispose()}; if([string]::IsNullOrWhiteSpace($env:VERIFY_HASH)){Write-Output ('Recorded SHA-256: ' + $actual); exit 0}; if($actual -ne $env:VERIFY_HASH){throw ('SHA-256 mismatch. Expected {0}, got {1}' -f $env:VERIFY_HASH,$actual)}; Write-Output ('Verified SHA-256: ' + $actual)" >>"%LOG%" 2>&1
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
set "CHECK_DIR=%RUNTIME%\setup-check"
if exist "%CHECK_DIR%" call :RemoveDirectoryRobust "%CHECK_DIR%"
if exist "%CHECK_DIR%" exit /b 1
mkdir "%CHECK_DIR%" >>"%LOG%" 2>&1
if not exist "%CHECK_DIR%" exit /b 1
"%APP_PY%" -I "%APP_FILE%" --self-test "%CHECK_DIR%" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
if not exist "%CHECK_DIR%\self-test-passed.txt" exit /b 1
call :RemoveDirectoryRobust "%CHECK_DIR%"
if exist "%CHECK_DIR%" exit /b 1
exit /b 0

:CreateShortcut
set "LINK_PATH=%ROOT%Video + Audio Downloader.lnk"
set "LEGACY_LINK_PATH=%ROOT%Video Downloader.lnk"
set "LINK_NEW=%RUNTIME%\shortcut.new.lnk"
set "LINK_BACKUP=%RUNTIME%\shortcut.previous.lnk"
set "LINK_TARGET=%APP_PYW%"
set "LINK_DIR=%ROOT%"
set "LINK_DESCRIPTION=Video + Audio Downloader"
set "LINK_ICON=%APP_PYW%,0"
if not exist "%LINK_TARGET%" exit /b 1
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $path=$env:LINK_PATH; $legacy=$env:LEGACY_LINK_PATH; $new=$env:LINK_NEW; $backup=$env:LINK_BACKUP; $arguments='-I '+[char]34+$env:APP_FILE+[char]34; $samePath={param($a,$b) [IO.Path]::GetFullPath($a).TrimEnd('\') -ieq [IO.Path]::GetFullPath($b).TrimEnd('\')}; $verify={param($shortcut,$stage) if(-not(& $samePath $shortcut.TargetPath $env:LINK_TARGET) -or $shortcut.Arguments -cne $arguments -or -not(& $samePath $shortcut.WorkingDirectory $env:LINK_DIR) -or $shortcut.Description -cne $env:LINK_DESCRIPTION -or [int]$shortcut.WindowStyle -ne 1 -or ($shortcut.IconLocation-replace ',\s+',',') -ine ($env:LINK_ICON-replace ',\s+',',') -or $shortcut.Hotkey){throw ($stage+' shortcut did not preserve its isolated launcher contract.')}}; if(Test-Path -LiteralPath $backup){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $backup -Force}else{Move-Item -LiteralPath $backup -Destination $path}}; if(Test-Path -LiteralPath $new){Remove-Item -LiteralPath $new -Force}; $shell=New-Object -ComObject WScript.Shell; $link=$shell.CreateShortcut($new); $link.TargetPath=$env:LINK_TARGET; $link.Arguments=$arguments; $link.WorkingDirectory=$env:LINK_DIR; $link.WindowStyle=1; $link.Description=$env:LINK_DESCRIPTION; $link.IconLocation=$env:LINK_ICON; $link.Hotkey=''; $link.Save(); $candidate=$shell.CreateShortcut($new); & $verify $candidate 'New'; $hadOld=Test-Path -LiteralPath $path; $movedOld=$false; try{if($hadOld){Move-Item -LiteralPath $path -Destination $backup; $movedOld=$true}; Move-Item -LiteralPath $new -Destination $path; $verified=$shell.CreateShortcut($path); & $verify $verified 'Installed'; if($legacy -and -not(& $samePath $legacy $path) -and (Test-Path -LiteralPath $legacy)){Remove-Item -LiteralPath $legacy -Force}; if(Test-Path -LiteralPath $backup){Remove-Item -LiteralPath $backup -Force}; Write-Output ('Created and validated shortcut: ' + $path)}catch{if($movedOld){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force}; if(Test-Path -LiteralPath $backup){Move-Item -LiteralPath $backup -Destination $path}}elseif(-not $hadOld -and (Test-Path -LiteralPath $path)){Remove-Item -LiteralPath $path -Force}; throw}finally{if(Test-Path -LiteralPath $new){Remove-Item -LiteralPath $new -Force}}" >>"%LOG%" 2>&1
if errorlevel 1 exit /b 1
if not exist "%LINK_PATH%" exit /b 1
exit /b 0

:LogCurrent
if not defined PATHS_VALIDATED exit /b 1
if not defined LOG_MESSAGE exit /b 0
"%POWERSHELL_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $line='[{0:yyyy-MM-dd HH:mm:ss.fff}] {1}{2}' -f [DateTime]::Now,$env:LOG_MESSAGE,[Environment]::NewLine; [IO.File]::AppendAllText($env:LOG,$line,[Text.UTF8Encoding]::new($false))" >nul 2>nul
set "LOG_MESSAGE="
exit /b %ERRORLEVEL%

:PauseIfNeeded
if "%NO_PAUSE%"=="1" exit /b 0
pause
exit /b 0
