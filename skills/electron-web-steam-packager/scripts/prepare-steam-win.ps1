[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BuildDir,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$GameKey,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Full', 'Demo')]
    [string]$Release,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^\\/:*?"<>|]+\.exe$')]
    [string]$EntryExecutable,

    [string]$ArchiveName,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$resolvedBuild = (Resolve-Path -LiteralPath $BuildDir).Path
if (-not (Get-Item -LiteralPath $resolvedBuild).PSIsContainer) {
    throw "BuildDir must be an unpacked directory: $resolvedBuild"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$resolvedOutput = (Resolve-Path -LiteralPath $OutputDir).Path

$nodeCommand = Get-Command node -ErrorAction Stop
$verifyScript = Join-Path $PSScriptRoot 'verify-artifact.mjs'
$verifyArguments = @(
    $verifyScript,
    '--platform', 'win',
    '--input', $resolvedBuild,
    '--expected-executable', $EntryExecutable
)
& $nodeCommand.Source @verifyArguments
if ($LASTEXITCODE -ne 0) {
    throw "Steam artifact verification failed with exit code $LASTEXITCODE"
}

$suffix = if ($Release -eq 'Demo') { '_Demo' } else { '' }
if ([string]::IsNullOrWhiteSpace($ArchiveName)) {
    $ArchiveName = 'Win_' + $GameKey + '_' + $Version + $suffix + '.zip'
}
if ([System.IO.Path]::GetFileName($ArchiveName) -ne $ArchiveName -or
    -not $ArchiveName.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'ArchiveName must be a plain .zip filename'
}

$destination = Join-Path $resolvedOutput $ArchiveName
$destinationFull = [System.IO.Path]::GetFullPath($destination)
$outputPrefix = [System.IO.Path]::GetFullPath($resolvedOutput).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
if (-not $destinationFull.StartsWith($outputPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Resolved archive target escaped OutputDir'
}
if (Test-Path -LiteralPath $destinationFull) {
    if (-not $Force) {
        throw "Archive already exists (use -Force to replace it): $destinationFull"
    }
    Remove-Item -LiteralPath $destinationFull -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$temporaryZip = Join-Path $resolvedOutput ('.' + [Guid]::NewGuid().ToString('N') + '.tmp.zip')
try {
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $resolvedBuild,
        $temporaryZip,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $archive = [System.IO.Compression.ZipFile]::OpenRead($temporaryZip)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        if ($entryNames -notcontains $EntryExecutable) {
            throw "Archive root is missing exact Steam executable: $EntryExecutable"
        }
        if (-not ($entryNames -contains 'resources/app.asar') -and
            -not ($entryNames | Where-Object { $_.StartsWith('resources/app/') })) {
            throw 'Archive is missing resources/app.asar or resources/app/'
        }
        $blockmaps = @($entryNames | Where-Object { $_.EndsWith('.blockmap') })
        if ($blockmaps.Count -gt 0) {
            throw "Archive contains forbidden blockmap files: $($blockmaps -join ', ')"
        }
    }
    finally {
        $archive.Dispose()
    }

    Move-Item -LiteralPath $temporaryZip -Destination $destinationFull
}
catch {
    if (Test-Path -LiteralPath $temporaryZip) {
        Remove-Item -LiteralPath $temporaryZip -Force
    }
    throw
}

$hash = (Get-FileHash -LiteralPath $destinationFull -Algorithm SHA256).Hash.ToLowerInvariant()
$hashPath = $destinationFull + '.sha256'
$hashLine = "$hash  $ArchiveName" + [Environment]::NewLine
[System.IO.File]::WriteAllText(
    $hashPath,
    $hashLine,
    [System.Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{
    schemaVersion = 1
    platform = 'win'
    release = $Release.ToLowerInvariant()
    version = $Version
    archive = $destinationFull
    sha256 = $hash
    sha256File = $hashPath
    entryExecutable = $EntryExecutable
} | ConvertTo-Json -Depth 3

