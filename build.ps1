[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = $PSScriptRoot
$infoPath = Join-Path $root 'info.json'
$distPath = Join-Path $root 'dist'

if (-not (Test-Path -LiteralPath $infoPath -PathType Leaf)) {
    throw "Missing mod metadata: $infoPath"
}

$metadata = Get-Content -LiteralPath $infoPath -Raw | ConvertFrom-Json
$modName = [string]$metadata.name
$version = [string]$metadata.version

if ([string]::IsNullOrWhiteSpace($modName)) {
    throw "info.json must contain a non-empty string 'name'."
}
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "info.json must contain a non-empty string 'version'."
}

$packageRoot = "${modName}_${version}"
$archivePath = Join-Path $distPath "${packageRoot}.zip"
$debugCommandsPath = Join-Path $distPath 'debug-commands.txt'
$excludedTopLevel = @(
    '.git',
    '.github',
    '.idea',
    '.vscode',
    'dist',
    'tools',
    '__pycache__'
)
$excludedFiles = @('.DS_Store', 'Thumbs.db')

$files = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
    $relativePath = $_.FullName.Substring($root.Length).TrimStart('\', '/')
    $topLevel = ($relativePath -split '[\\/]')[0]

    $excludedTopLevel -notcontains $topLevel -and
        $excludedFiles -notcontains $_.Name -and
        $_.Extension -notin @('.pyc', '.pyo')
} | Sort-Object FullName

if (-not ($files | Where-Object { $_.FullName -eq $infoPath })) {
    throw 'info.json would not be included in the package.'
}

if (Test-Path -LiteralPath $distPath) {
    Remove-Item -LiteralPath $distPath -Recurse -Force
}
New-Item -ItemType Directory -Path $distPath | Out-Null

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::Open(
    $archivePath,
    [System.IO.Compression.ZipArchiveMode]::Create
)

try {
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($root.Length).TrimStart('\', '/')
        $entryName = ($packageRoot + '/' + $relativePath.Replace('\', '/'))
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $file.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $archive.Dispose()
}

$verificationArchive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $entryNames = @($verificationArchive.Entries | ForEach-Object { $_.FullName })
    $expectedPrefix = "${packageRoot}/"

    if ($entryNames.Count -eq 0) {
        throw 'The generated archive is empty.'
    }
    if ($entryNames | Where-Object { -not $_.StartsWith($expectedPrefix) }) {
        throw "Every ZIP entry must be inside ${expectedPrefix}."
    }
    if ($entryNames -notcontains "${expectedPrefix}info.json") {
        throw 'The generated archive does not contain info.json at the mod root.'
    }
    if ($entryNames -notcontains "${expectedPrefix}control.lua") {
        throw 'The generated archive does not contain control.lua at the mod root.'
    }
}
finally {
    $verificationArchive.Dispose()
}

$debugCommands = @"
Railwright $version - Debug Commands
====================================

Experimental diagonal stackers
    The Railwright stacker panel shows a
    "Diagonal stacker (experimental)" checkbox by default.
    To hide it, open Settings > Mod settings > Per player and disable
    "Show experimental diagonal stacker option" for Railwright.

/railwright-debug-stackers
    Toggles stacker blueprint diagnostics for the current player.
    When enabled, diagnostic output is written to factorio-current.log.
    Run it again to disable diagnostics.

Recommended diagonal test setup
-------------------------------
1. Run /railwright-debug-stackers
2. Open Railwright and select Stacker.
3. Enable "Diagonal stacker (experimental)" and create the blueprint.
4. Inspect the generated blueprint and factorio-current.log.

Relevant log prefix:
[Railwright][blueprint-debug][diagonal-signal]
"@

[System.IO.File]::WriteAllText(
    $debugCommandsPath,
    $debugCommands,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Built dist/$packageRoot.zip"
Write-Host 'Built dist/debug-commands.txt'
Write-Host "Package root: $packageRoot"
Write-Host "Files included: $($files.Count)"
