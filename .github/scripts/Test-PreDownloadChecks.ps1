$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$scratchParent = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$scratch = Join-Path $scratchParent ('vp' + [Guid]::NewGuid().ToString('N').Substring(0, 5))
$cmd = Join-Path $env:SystemRoot 'System32\cmd.exe'
New-Item -ItemType Directory -Path $scratch -ErrorAction Stop | Out-Null

function New-Fixture([string]$Name, [switch]$WithSource, [switch]$WithLicense) {
    $root = Join-Path $scratch $Name
    New-Item -ItemType Directory -Path $root -ErrorAction Stop | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository 'Installer.bat') -Destination $root
    if ($WithSource) {
        Copy-Item -LiteralPath (Join-Path $repository 'Video + Audio Downloader.pyw') -Destination $root
    }
    if ($WithLicense) {
        Copy-Item -LiteralPath (Join-Path $repository 'LICENSE') -Destination $root
    }
    return $root
}

function Invoke-Fixture([string]$Root) {
    $installer = Join-Path $Root 'Installer.bat'
    $lines = & $cmd /d /c ('call "{0}" --yes --no-pause' -f $installer) 2>&1
    return [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($lines -join "`n") }
}

function Assert-EarlyFailure([string]$Root, $Result, [string]$Expected) {
    if ($Result.Code -eq 0) { throw "Unexpected successful setup in $Root" }
    if (-not $Result.Text.Contains($Expected)) { throw "Missing expected failure '$Expected' in $Root`: $($Result.Text)" }
    if (-not $Result.Text.Contains('How to fix:') -and -not $Result.Text.Contains('Move the extracted folder closer')) {
        throw "No actionable repair instruction in $Root`: $($Result.Text)"
    }
    foreach ($path in @('.runtime\python', '.runtime\downloads\python-3.14.7-embed-x64.zip', '.runtime\downloads\python-3.14.7-embed-arm64.zip', '.runtime\setup-complete.txt')) {
        if (Test-Path -LiteralPath (Join-Path $Root $path)) {
            throw "Pre-download failure allowed Python setup or success marker in $Root`: $path"
        }
    }
    $log = Join-Path $Root 'setup.log'
    if (Test-Path -LiteralPath $log) {
        $text = Get-Content -LiteralPath $log -Raw
        if ($text -match '(?m)Downloading: https://|Official embedded CPython passed local validation') {
            throw "Pre-download failure started runtime downloads in $Root"
        }
    }
    Write-Host "Passed early failure test: $Expected"
}

$missingLicense = New-Fixture 'missing license' -WithSource
Assert-EarlyFailure $missingLicense (Invoke-Fixture $missingLicense) 'bundled Tool License is missing'

$missingSource = New-Fixture 'missing source' -WithLicense
Assert-EarlyFailure $missingSource (Invoke-Fixture $missingSource) 'Video + Audio Downloader.pyw is missing'

$emptySource = New-Fixture 'empty source' -WithLicense -WithSource
[IO.File]::WriteAllBytes((Join-Path $emptySource 'Video + Audio Downloader.pyw'), [byte[]]@())
Assert-EarlyFailure $emptySource (Invoke-Fixture $emptySource) 'bundled app source is empty, unreadable, or unsafe'

$blockedShortcut = New-Fixture 'blocked shortcut' -WithLicense -WithSource
New-Item -ItemType Directory -Path (Join-Path $blockedShortcut 'Video + Audio Downloader.lnk') | Out-Null
Assert-EarlyFailure $blockedShortcut (Invoke-Fixture $blockedShortcut) 'Windows could not create or read back a folder-local start shortcut'
$blockedLog = Get-Content -LiteralPath (Join-Path $blockedShortcut 'setup.log') -Raw
if ($blockedLog -notmatch 'Bundled app source passed preflight' -or $blockedLog -notmatch 'Windows ZIP extraction passed preflight') {
    throw 'The blocked-shortcut fixture did not first pass source and ZIP checks.'
}

$longRoot = New-Fixture ('long-path-' + ('x' * 80)) -WithLicense -WithSource
Assert-EarlyFailure $longRoot (Invoke-Fixture $longRoot) 'complete app folder path must be 72 characters or fewer'

Write-Host 'All no-download prerequisite failure checks passed in paths containing spaces.'
exit 0
