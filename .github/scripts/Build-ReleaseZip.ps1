param(
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

# Match the seven-file public release contract; never recursively ZIP the checkout.
$releaseFiles = @(
    'Installer.bat',
    'LICENSE',
    'READ ME.txt',
    'Video + Audio Downloader.pyw',
    'Video Downloader.pyw',
    'requirements-win-x64.txt',
    'requirements-win-arm64.txt'
)
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$output = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $output) { throw "Release ZIP already exists: $output" }
if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($output)) -PathType Container)) {
    throw 'The output directory must already exist.'
}
Push-Location -LiteralPath $repository
try {
    & git diff --quiet --exit-code HEAD -- $releaseFiles
    if ($LASTEXITCODE -ne 0) { throw 'Commit release file changes before building the canonical ZIP.' }

    $gitExe = (Get-Command git -ErrorAction Stop).Source
    function Read-CommittedBlob([string]$Name) {
        $oid = (& $gitExe rev-parse ('HEAD:' + $Name)).Trim()
        if ($LASTEXITCODE -ne 0 -or $oid -notmatch '^[0-9a-f]{40,64}$') {
            throw "Could not resolve the committed Git blob for $Name"
        }
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $gitExe
        $start.Arguments = 'cat-file blob ' + $oid
        $start.WorkingDirectory = $repository
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $process = [Diagnostics.Process]::Start($start)
        if (-not $process) { throw "Could not read the committed Git blob for $Name" }
        try {
            $buffer = [IO.MemoryStream]::new()
            try {
                $process.StandardOutput.BaseStream.CopyTo($buffer)
                $process.WaitForExit()
                if ($process.ExitCode -ne 0) {
                    throw "git cat-file failed for ${Name}: $($process.StandardError.ReadToEnd())"
                }
                return ,$buffer.ToArray()
            } finally { $buffer.Dispose() }
        } finally { $process.Dispose() }
    }

    $appText = [Text.UTF8Encoding]::new($false, $true).GetString((Read-CommittedBlob 'Video + Audio Downloader.pyw'))
    $versionMatch = [regex]::Match($appText, '(?m)^APP_VERSION = "(?<version>\d+\.\d+\.\d+)"\s*$')
    if (-not $versionMatch.Success) { throw 'The committed app has no unambiguous release version.' }
    $version = $versionMatch.Groups['version'].Value
    if ([IO.Path]::GetFileName($output) -cne "Video-Audio-Downloader-v$version.zip") {
        throw "The release ZIP filename must be Video-Audio-Downloader-v$version.zip."
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $content = @{}
    foreach ($name in $releaseFiles) {
        $bytes = Read-CommittedBlob $name
        if ($name -eq 'Installer.bat') {
            # .gitattributes specifies Windows CRLF at checkout. Recreate it from the blob.
            $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
            $text = $text.Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
            $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
        }
        $content[$name] = $bytes
    }

    $fileStream = [IO.File]::Open($output, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $archive = [IO.Compression.ZipArchive]::new($fileStream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($name in $releaseFiles) {
                $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]::Parse('2000-01-01T00:00:00Z')
                $entry.ExternalAttributes = 0
                $stream = $entry.Open()
                try { $stream.Write($content[$name], 0, $content[$name].Length) }
                finally { $stream.Dispose() }
            }
        } finally { $archive.Dispose() }
    } finally { $fileStream.Dispose() }

    $archive = [IO.Compression.ZipFile]::OpenRead($output)
    try {
        if ($archive.Entries.Count -ne $releaseFiles.Count) { throw 'Release ZIP has an unexpected number of entries.' }
        for ($index = 0; $index -lt $releaseFiles.Count; $index++) {
            $name = $releaseFiles[$index]
            $entry = $archive.Entries[$index]
            if ($entry.FullName -cne $name) { throw "Unexpected release ZIP entry: $($entry.FullName)" }
            $actual = [IO.MemoryStream]::new()
            try {
                $entryStream = $entry.Open()
                try { $entryStream.CopyTo($actual) } finally { $entryStream.Dispose() }
                $sha = [Security.Cryptography.SHA256]::Create()
                try {
                    $expectedHash = [BitConverter]::ToString($sha.ComputeHash([byte[]]$content[$name]))
                    $actualHash = [BitConverter]::ToString($sha.ComputeHash([byte[]]$actual.ToArray()))
                } finally { $sha.Dispose() }
                if ($expectedHash -cne $actualHash) {
                    throw "Release ZIP entry bytes changed: $name"
                }
            } finally { $actual.Dispose() }
        }
    } finally { $archive.Dispose() }

    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    $size = (Get-Item -LiteralPath $output).Length
    Write-Host "Built $output"
    Write-Host "$($releaseFiles.Count) verified files; $size bytes; SHA-256 $hash"
} finally {
    Pop-Location
}
