[CmdletBinding()]
param(
    [string[]]$PackagePath,
    [switch]$PlanOnly,
    [switch]$DryRun,
    [switch]$AllowPlaceholderConfig
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ConfigPath = Join-Path $Script:Root "config\games.json"
$Script:Workspace = Join-Path $Script:Root "workspace"
$Script:NamePattern = '^(Win|Mac)_([A-Za-z0-9]+)_([0-9]+\.[0-9]+\.[0-9]+)(_Demo)?\.zip$'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Split-DraggedPaths {
    param([string]$InputText)

    $paths = New-Object System.Collections.Generic.List[string]
    $matches = [regex]::Matches($InputText, '"([^"]+)"|''([^'']+)''|(\S+)')
    foreach ($match in $matches) {
        $value = $match.Groups[1].Value
        if ([string]::IsNullOrWhiteSpace($value)) { $value = $match.Groups[2].Value }
        if ([string]::IsNullOrWhiteSpace($value)) { $value = $match.Groups[3].Value }
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $paths.Add($value.Trim())
        }
    }
    return $paths.ToArray()
}

function Get-PackagePaths {
    if ($PackagePath -and $PackagePath.Count -gt 0) {
        $paths = New-Object System.Collections.Generic.List[string]
        foreach ($item in $PackagePath) {
            foreach ($part in ($item -split ',')) {
                $trimmed = $part.Trim()
                if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                    $paths.Add($trimmed)
                }
            }
        }
        return $paths.ToArray()
    }

    Write-Host ""
    Write-Host "Drag one or more .zip packages here, then press Enter:"
    $inputText = Read-Host
    $paths = Split-DraggedPaths -InputText $inputText
    if ($paths.Count -eq 0) {
        throw "No package path was provided."
    }
    return $paths
}

function Load-Config {
    if (-not (Test-Path -LiteralPath $Script:ConfigPath)) {
        throw "Missing config file: $Script:ConfigPath"
    }

    $raw = Get-Content -LiteralPath $Script:ConfigPath -Raw -Encoding UTF8
    return $raw | ConvertFrom-Json
}

function Test-Placeholder {
    param([string]$Value)
    return [string]::IsNullOrWhiteSpace($Value) -or $Value -like "TODO*"
}

function Resolve-GameConfig {
    param(
        [object]$Config,
        [string]$Game,
        [bool]$IsDemo,
        [string]$Platform
    )

    if (-not $Config.games.PSObject.Properties.Name.Contains($Game)) {
        throw "Game '$Game' is not configured in $Script:ConfigPath."
    }

    $releaseKey = if ($IsDemo) { "demo" } else { "full" }
    $gameConfig = $Config.games.$Game
    if (-not $gameConfig.PSObject.Properties.Name.Contains($releaseKey)) {
        throw "Game '$Game' does not have '$releaseKey' config."
    }

    $releaseConfig = $gameConfig.$releaseKey
    if (-not $releaseConfig.depots.PSObject.Properties.Name.Contains($Platform)) {
        throw "Game '$Game' '$releaseKey' does not have a $Platform depot config."
    }

    $appId = [string]$releaseConfig.appId
    $depotId = [string]$releaseConfig.depots.$Platform
    if ((Test-Placeholder $appId) -or (Test-Placeholder $depotId)) {
        if (-not $AllowPlaceholderConfig) {
            throw "Game '$Game' '$releaseKey' has placeholder AppID/DepotID. Edit $Script:ConfigPath first, or use -AllowPlaceholderConfig for parsing tests."
        }
    }

    return [pscustomobject]@{
        AppId = $appId
        DepotId = $depotId
        ReleaseKey = $releaseKey
    }
}

function Parse-Package {
    param(
        [string]$Path,
        [object]$Config
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $file = Get-Item -LiteralPath $resolved.Path

    if ($file.Extension -ieq ".rar") {
        throw "Unsupported archive '$($file.Name)'. Please provide .zip files named like Win_Game_1.2.3_Demo.zip."
    }

    $match = [regex]::Match($file.Name, $Script:NamePattern)
    if (-not $match.Success) {
        throw "Invalid file name '$($file.Name)'. Expected: Win_Game_1.2.3.zip, Mac_Game_1.2.3.zip, Win_Game_1.2.3_Demo.zip, or Mac_Game_1.2.3_Demo.zip."
    }

    $platform = $match.Groups[1].Value
    $game = $match.Groups[2].Value
    $version = $match.Groups[3].Value
    $isDemo = $match.Groups[4].Success
    $resolvedConfig = Resolve-GameConfig -Config $Config -Game $game -IsDemo $isDemo -Platform $platform

    return [pscustomobject]@{
        SourcePath = $file.FullName
        FileName = $file.Name
        Platform = $platform
        Game = $game
        Version = $version
        IsDemo = $isDemo
        ReleaseKey = $resolvedConfig.ReleaseKey
        AppId = $resolvedConfig.AppId
        DepotId = $resolvedConfig.DepotId
    }
}

function Group-Packages {
    param([object[]]$Packages)

    $groups = @{}
    foreach ($pkg in $Packages) {
        $key = "$($pkg.AppId)|$($pkg.Game)|$($pkg.ReleaseKey)|$($pkg.Version)"
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = [ordered]@{
                Key = $key
                AppId = $pkg.AppId
                Game = $pkg.Game
                Version = $pkg.Version
                ReleaseKey = $pkg.ReleaseKey
                Packages = @()
            }
        }

        $existingPlatform = @($groups[$key].Packages | Where-Object { $_.Platform -eq $pkg.Platform })
        if ($existingPlatform.Count -gt 0) {
            throw "Duplicate $($pkg.Platform) package in task '$key'."
        }
        $groups[$key].Packages += $pkg
    }

    return @($groups.Values | ForEach-Object { [pscustomobject]$_ })
}

function Ensure-CleanDirectory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
        return
    }

    $workspaceRoot = [System.IO.Path]::GetFullPath($Script:Workspace)
    $target = [System.IO.Path]::GetFullPath($Path)
    if (-not $target.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean outside workspace: $Path"
    }

    Get-ChildItem -LiteralPath $Path -Force | Remove-Item -Recurse -Force
}

function Remove-MacJunk {
    param([string]$Path)

    Get-ChildItem -LiteralPath $Path -Force -Recurse -Directory -Filter "__MACOSX" -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force
    Get-ChildItem -LiteralPath $Path -Force -Recurse -File -Filter ".DS_Store" -ErrorAction SilentlyContinue |
        Remove-Item -Force
}

function Get-EffectiveContentRoot {
    param([string]$Path)

    $items = @(Get-ChildItem -LiteralPath $Path -Force | Where-Object { $_.Name -notin @("__MACOSX", ".DS_Store") })
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
        return $items[0].FullName
    }
    return $Path
}

function Ensure-EntryName {
    param(
        [string]$ContentDir,
        [string]$Platform
    )

    $root = Get-EffectiveContentRoot -Path $ContentDir
    if ($Platform -eq "Win") {
        $targetName = "game.exe"
        $candidates = @(Get-ChildItem -LiteralPath $root -Force -File -Filter "*.exe")
    } else {
        $targetName = "game.app"
        $rootItem = Get-Item -LiteralPath $root
        if ($rootItem.PSIsContainer -and $rootItem.Name -like "*.app") {
            $candidates = @($rootItem)
        } else {
            $candidates = @(Get-ChildItem -LiteralPath $root -Force -Directory -Filter "*.app")
        }
    }

    if ($candidates.Count -eq 0) {
        throw "No $targetName candidate found in '$root'."
    }
    if ($candidates.Count -gt 1) {
        $names = ($candidates | ForEach-Object { $_.Name }) -join ", "
        throw "Multiple entry candidates found in '$root': $names. Please keep only one."
    }

    $entry = $candidates[0]
    if ($entry.Name -eq $targetName) {
        Write-Info "$Platform entry is already $targetName."
        return [pscustomobject]@{
            Changed = $false
            Before = $entry.Name
            After = $targetName
            Root = $root
        }
    }

    $parentDir = if ($entry.PSIsContainer) { $entry.Parent.FullName } else { $entry.DirectoryName }
    $targetPath = Join-Path $parentDir $targetName
    if (Test-Path -LiteralPath $targetPath) {
        throw "Cannot rename '$($entry.Name)' to '$targetName' because target already exists."
    }

    Rename-Item -LiteralPath $entry.FullName -NewName $targetName
    Write-Warn "$Platform entry renamed: $($entry.Name) -> $targetName"
    return [pscustomobject]@{
        Changed = $true
        Before = $entry.Name
        After = $targetName
        Root = $root
    }
}

function Expand-Package {
    param([object]$Package)

    $archiveDir = Join-Path $Script:Workspace "archives"
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    $archiveCopy = Join-Path $archiveDir $Package.FileName
    Copy-Item -LiteralPath $Package.SourcePath -Destination $archiveCopy -Force

    $platformDir = if ($Package.Platform -eq "Win") { "win_build" } else { "mac_build" }
    $contentDir = Join-Path (Join-Path (Join-Path $Script:Workspace "content") $Package.AppId) $platformDir
    Ensure-CleanDirectory -Path $contentDir

    Write-Info "Extracting $($Package.FileName) -> $contentDir"
    Expand-Archive -LiteralPath $archiveCopy -DestinationPath $contentDir -Force
    Remove-MacJunk -Path $contentDir
    $entry = Ensure-EntryName -ContentDir $contentDir -Platform $Package.Platform

    return [pscustomobject]@{
        Package = $Package
        ContentDir = $contentDir
        Entry = $entry
    }
}

function ConvertTo-VdfString {
    param([string]$Value)
    return $Value.Replace('\', '/').Replace('"', '\"')
}

function Write-DepotVdf {
    param(
        [string]$Path,
        [string]$DepotId,
        [string]$ContentRoot
    )

    $contentRootValue = ConvertTo-VdfString -Value $ContentRoot
    $text = @"
"DepotBuildConfig"
{
    "DepotID" "$DepotId"
    "ContentRoot" "$contentRootValue"
    "FileMapping"
    {
        "LocalPath" "*"
        "DepotPath" "."
        "recursive" "1"
    }
    "FileExclusion" "*.DS_Store"
    "FileExclusion" "__MACOSX"
}
"@
    Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
}

function Write-AppVdf {
    param(
        [string]$Path,
        [string]$AppId,
        [string]$Description,
        [string]$BuildOutput,
        [string]$ContentRoot,
        [string]$SetLive,
        [object[]]$DepotEntries
    )

    $outputValue = ConvertTo-VdfString -Value $BuildOutput
    $contentRootValue = ConvertTo-VdfString -Value $ContentRoot
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('"appbuild"')
    $lines.Add('{')
    $lines.Add("    `"appid`" `"$AppId`"")
    $lines.Add("    `"desc`" `"$Description`"")
    $lines.Add("    `"buildoutput`" `"$outputValue`"")
    $lines.Add("    `"contentroot`" `"$contentRootValue`"")
    if (-not [string]::IsNullOrWhiteSpace($SetLive)) {
        $lines.Add("    `"setlive`" `"$SetLive`"")
    }
    $lines.Add('    "depots"')
    $lines.Add('    {')
    foreach ($entry in $DepotEntries) {
        $scriptName = Split-Path -Leaf $entry.VdfPath
        $lines.Add("        `"$($entry.DepotId)`" `"$scriptName`"")
    }
    $lines.Add('    }')
    $lines.Add('}')
    Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
}

function New-VdfFiles {
    param(
        [object]$Task,
        [object[]]$PreparedPackages,
        [object]$Config
    )

    $scriptDir = Join-Path (Join-Path $Script:Workspace "scripts") $Task.AppId
    $outputDir = Join-Path (Join-Path $Script:Workspace "output") $Task.AppId
    $contentRoot = Join-Path (Join-Path $Script:Workspace "content") $Task.AppId
    New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    $depotEntries = @()
    foreach ($prepared in $PreparedPackages) {
        $pkg = $prepared.Package
        $platformDir = if ($pkg.Platform -eq "Win") { "win_build/" } else { "mac_build/" }
        $depotPath = Join-Path $scriptDir "depot_build_$($pkg.DepotId).vdf"
        Write-DepotVdf -Path $depotPath -DepotId $pkg.DepotId -ContentRoot $platformDir
        $depotEntries += [pscustomobject]@{
            DepotId = $pkg.DepotId
            VdfPath = $depotPath
            Platform = $pkg.Platform
        }
    }

    $platformDesc = (($Task.Packages | Sort-Object Platform | ForEach-Object { $_.Platform }) -join "")
    $desc = "$($Task.Game)_$($Task.Version)_$($Task.ReleaseKey)_${platformDesc}_Auto"
    $appPath = Join-Path $scriptDir "app_build_$($Task.AppId).vdf"
    Write-AppVdf -Path $appPath -AppId $Task.AppId -Description $desc -BuildOutput $outputDir -ContentRoot $contentRoot -SetLive ([string]$Config.setLive) -DepotEntries $depotEntries

    return [pscustomobject]@{
        AppVdf = $appPath
        DepotVdfs = $depotEntries
        OutputDir = $outputDir
        Description = $desc
    }
}

function Invoke-SteamUpload {
    param(
        [object]$Task,
        [object]$VdfInfo,
        [object]$Config
    )

    $steamCmdPath = [string]$Config.steamCmdPath
    if ([string]::IsNullOrWhiteSpace($steamCmdPath)) {
        $steamCmdPath = "builder\steamcmd.exe"
    }
    if (-not [System.IO.Path]::IsPathRooted($steamCmdPath)) {
        $steamCmdPath = Join-Path $Script:Root $steamCmdPath
    }

    if (-not (Test-Path -LiteralPath $steamCmdPath)) {
        throw "SteamCMD not found: $steamCmdPath. Put steamcmd.exe there or edit config\games.json."
    }

    $steamUser = [string]$Config.steamUser
    if ([string]::IsNullOrWhiteSpace($steamUser)) {
        throw "Config steamUser is empty."
    }

    Write-Info "Uploading AppID $($Task.AppId) with $steamCmdPath"
    & $steamCmdPath +login $steamUser +run_app_build $VdfInfo.AppVdf +quit
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "SteamCMD failed for AppID $($Task.AppId) with exit code $exitCode. Output: $($VdfInfo.OutputDir)"
    }
}

function Show-Plan {
    param([object[]]$Tasks)

    Write-Host ""
    Write-Host "Upload task plan:"
    foreach ($task in $Tasks) {
        $platforms = ($task.Packages | Sort-Object Platform | ForEach-Object { "$($_.Platform):Depot $($_.DepotId)" }) -join ", "
        Write-Host "- AppID $($task.AppId) | $($task.Game) | $($task.Version) | $($task.ReleaseKey) | $platforms"
    }
}

function Prompt-OpenSteamworks {
    param([object[]]$SucceededTasks)

    if ($SucceededTasks.Count -eq 0) { return }

    Write-Host ""
    foreach ($task in $SucceededTasks) {
        $url = "https://partner.steamgames.com/apps/builds/$($task.AppId)"
        Write-Host "Steamworks: $url"
        $answer = Read-Host "Open this page now? (Y/N)"
        if ($answer -match '^(y|yes)$') {
            Start-Process $url
        }
    }
}

try {
    Write-Host "======= Steam Windows Upload Tool =======" -ForegroundColor Green
    if ($PlanOnly) { Write-Warn "PlanOnly mode: no copy, extract, VDF generation, or upload." }
    elseif ($DryRun) { Write-Warn "DryRun mode: copy, extract, and VDF generation only; SteamCMD will not run." }

    $config = Load-Config
    $paths = Get-PackagePaths
    $packages = @()
    foreach ($path in $paths) {
        $packages += Parse-Package -Path $path -Config $config
    }

    Write-Host ""
    $packages | Sort-Object Game, ReleaseKey, Version, Platform |
        Format-Table Platform, Game, Version, ReleaseKey, AppId, DepotId, FileName -AutoSize

    $tasks = Group-Packages -Packages $packages
    Show-Plan -Tasks $tasks

    if ($PlanOnly) {
        Write-Info "Plan complete."
        exit 0
    }

    $succeeded = @()
    foreach ($task in $tasks) {
        Write-Host ""
        Write-Info "Preparing AppID $($task.AppId): $($task.Game) $($task.Version) $($task.ReleaseKey)"
        $prepared = @()
        foreach ($pkg in $task.Packages) {
            $prepared += Expand-Package -Package $pkg
        }

        $vdfInfo = New-VdfFiles -Task $task -PreparedPackages $prepared -Config $config
        Write-Info "Generated app VDF: $($vdfInfo.AppVdf)"
        Write-Info "Build description: $($vdfInfo.Description)"

        if ($DryRun) {
            Write-Warn "DryRun skipped SteamCMD for AppID $($task.AppId)."
            $succeeded += $task
            continue
        }

        Invoke-SteamUpload -Task $task -VdfInfo $vdfInfo -Config $config
        Write-Info "Upload finished for AppID $($task.AppId). Output: $($vdfInfo.OutputDir)"
        $succeeded += $task
    }

    Prompt-OpenSteamworks -SucceededTasks $succeeded
    Write-Host ""
    Write-Host "======= Done =======" -ForegroundColor Green
}
catch {
    Write-Err $_.Exception.Message
    Write-Host ""
    Write-Host "Required file name format:"
    Write-Host "  Win_GameName_1.2.3.zip"
    Write-Host "  Mac_GameName_1.2.3.zip"
    Write-Host "  Win_GameName_1.2.3_Demo.zip"
    Write-Host "  Mac_GameName_1.2.3_Demo.zip"
    exit 1
}
