[CmdletBinding()]
param(
    [string]$InstallDir,
    [string]$Url,
    [ValidateRange(1, 5)]
    [int]$BootstrapAttempts = 3,
    [ValidateRange(30, 600)]
    [int]$BootstrapTimeoutSeconds = 300
)

# Install the Windows SteamCMD distribution used by SteamPackFlow.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Join-Path $scriptRoot "builder"
}
if ([string]::IsNullOrWhiteSpace($Url)) {
    $Url = [string]$env:STEAMCMD_URL
}
if ([string]::IsNullOrWhiteSpace($Url)) {
    $Url = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Test-SteamCmdReady {
    param([string]$Path)

    return ((Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -gt 0)
}

function Initialize-SteamCmd {
    param(
        [string]$Path,
        [string]$WorkingDirectory
    )

    for ($attempt = 1; $attempt -le $BootstrapAttempts; $attempt++) {
        Write-Info "Bootstrapping SteamCMD (attempt $attempt of $BootstrapAttempts)..."

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $Path
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.Arguments = "+quit"
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        try {
            if (-not $process.Start()) {
                throw "Could not start SteamCMD: $Path"
            }

            $process.StandardInput.Close()
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit($BootstrapTimeoutSeconds * 1000)) {
                try { $process.Kill() } catch {}
                throw "SteamCMD bootstrap timed out after $BootstrapTimeoutSeconds seconds."
            }

            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            if (-not [string]::IsNullOrWhiteSpace($stdout)) {
                Write-Host $stdout.TrimEnd()
            }
            if (-not [string]::IsNullOrWhiteSpace($stderr)) {
                Write-Warning $stderr.TrimEnd()
            }

            if ($process.ExitCode -eq 0) {
                Write-Info "SteamCMD bootstrap completed."
                return
            }

            if ($attempt -lt $BootstrapAttempts) {
                Write-Warning "SteamCMD bootstrap exited with code $($process.ExitCode). Retrying because SteamCMD may have replaced itself during the first update."
            }
            else {
                throw "SteamCMD bootstrap failed after $BootstrapAttempts attempts; final exit code $($process.ExitCode)."
            }
        }
        finally {
            $process.Dispose()
        }
    }
}

function Remove-SafeTemporaryDirectory {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return
    }

    $resolved = [System.IO.Path]::GetFullPath($Path)
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    $leaf = Split-Path -Leaf $resolved
    if (-not $resolved.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $leaf -notlike "steampackflow-steamcmd-*") {
        throw "Refusing to clean unexpected temporary directory: $resolved"
    }

    Remove-Item -LiteralPath $resolved -Recurse -Force
}

$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$target = Join-Path $InstallDir "steamcmd.exe"
if (Test-SteamCmdReady -Path $target) {
    Write-Info "SteamCMD is already installed: $target"
}
else {
    $temporaryDir = Join-Path ([System.IO.Path]::GetTempPath()) ("steampackflow-steamcmd-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $temporaryDir | Out-Null

    try {
        $archive = Join-Path $temporaryDir "steamcmd.zip"
        $extractDir = Join-Path $temporaryDir "extracted"
        New-Item -ItemType Directory -Path $extractDir | Out-Null

        Write-Info "Downloading SteamCMD from $Url"
        Invoke-WebRequest -Uri $Url -OutFile $archive -UseBasicParsing
        Expand-Archive -LiteralPath $archive -DestinationPath $extractDir -Force

        $candidates = @(Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter "steamcmd.exe")
        if ($candidates.Count -ne 1) {
            throw "Expected exactly one steamcmd.exe in the downloaded archive; found $($candidates.Count)."
        }

        $sourceRoot = $candidates[0].Directory.FullName
        Get-ChildItem -LiteralPath $sourceRoot -Force |
            Copy-Item -Destination $InstallDir -Recurse -Force
    }
    finally {
        Remove-SafeTemporaryDirectory -Path $temporaryDir
    }
}

if (-not (Test-SteamCmdReady -Path $target)) {
    throw "SteamCMD was extracted, but steamcmd.exe is missing or empty at $target"
}

Write-Info "SteamCMD installed: $target"
Initialize-SteamCmd -Path $target -WorkingDirectory $InstallDir
