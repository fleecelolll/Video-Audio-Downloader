param(
    [Parameter(Mandatory = $true)][string]$ReleaseRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$root = [IO.Path]::GetFullPath($ReleaseRoot).TrimEnd('\')
$shortcut = Join-Path $root 'Video + Audio Downloader.lnk'
$pythonw = Join-Path $root '.runtime\python\pythonw.exe'
$app = Join-Path $root 'Video + Audio Downloader.pyw'
foreach ($path in @($shortcut, $pythonw, $app)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Installed launch component is missing: $path" }
}
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcut)
if ([IO.Path]::GetFullPath($link.TargetPath) -ine [IO.Path]::GetFullPath($pythonw)) { throw 'Shortcut points to the wrong Python runtime.' }
if ($link.Arguments -cne ('-I "' + $app + '"')) { throw 'Shortcut arguments do not target the released app.' }
if ([IO.Path]::GetFullPath($link.WorkingDirectory).TrimEnd('\') -ine $root) { throw 'Shortcut working directory is wrong.' }

$before = @(Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" | ForEach-Object ProcessId)
$launched = @()
try {
    Start-Process -FilePath $shortcut -WindowStyle Hidden | Out-Null
    $deadline = (Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 500
        $launched = @(Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" | Where-Object {
            $_.ProcessId -notin $before -and
            $_.ExecutablePath -ieq $pythonw -and
            [string]$_.CommandLine -like '*Video + Audio Downloader.pyw*'
        })
    } until ($launched.Count -gt 0 -or (Get-Date) -ge $deadline)
    if ($launched.Count -ne 1) { throw "Expected one running app launched by the shortcut; found $($launched.Count)." }
    Write-Host 'Folder-local shortcut target, arguments, and actual app launch passed.'
} finally {
    foreach ($process in $launched) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}
