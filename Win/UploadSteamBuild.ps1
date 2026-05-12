[CmdletBinding()]
param(
    [string[]]$PackagePath,
    [string]$SteamUser,
    [string]$ConfigPath,
    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN",
    [switch]$PlanOnly,
    [switch]$DryRun,
    [switch]$AllowPlaceholderConfig
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ConfigPath = if ([string]::IsNullOrWhiteSpace($ConfigPath)) { Join-Path $Script:Root "config\games.json" } else { $ConfigPath }
$Script:Workspace = Join-Path $Script:Root "workspace"
$Script:Inbox = Join-Path $Script:Root "inbox"
$Script:NamePattern = '^(Win|Mac)_([A-Za-z0-9]+)_([0-9]+\.[0-9]+\.[0-9]+)(_Demo)?\.zip$'
$Script:InteractiveMode = -not ($PackagePath -and $PackagePath.Count -gt 0)
$zhJsonBase64 = @(
    "eyJJbmZvUHJlZml4IjoiW+S/oeaBr10iLCJXYXJuUHJlZml4IjoiW+itpuWRil0iLCJFcnJvclByZWZpeCI6IlvplJnor69dIiwiVGl0bGUiOiI9PT09PT09IFN0ZWFtIFdpbmRvd3Mg5LiK5Lyg5bel5YW3ID09PT09PT0iLCJQbGFuT25seU1vZGUiOiLorqHliJLpooTop4jmqKHlvI/vvJrkuI3kvJrlpI3liLbjgIHop6PljovjgIHnlJ/miJAgVkRGIOaIluS4iuS8oOOAgiIsIkRyeVJ1bk1vZGUiOiLlubLot5HmqKHlvI/vvJrlj6rlpI3liLbjgIHop6PljovlubbnlJ/miJAgVkRG77yM5LiN5Lya6LCD55SoIFN0ZWFtQ01EIOS4iuS8oOOAgiIsIkluYm94SW50cm8iOiLor7fmiorkuIDkuKrmiJblpJrkuKogLnppcCDljIXlpI3liLbliLDov5nkuKrmlofku7blpLnvvJoiLCJJbmJveE9wZW4iOiLnjrDlnKjkvJroh6rliqjmiZPlvIDor6Xmlofku7blpLnjgILlpI3liLblrozmiJDlkI7vvIzor7flm57liLDov5nkuKrnqpflj6PlubbmjIkgRW50ZXIg57un57ut44CCIiwiSW5ib3hPcGVuRmFpbGVkIjoi5peg5rOV6Ieq5Yqo5omT5byA5paH5Lu25aS577yaezB9IiwiSW5ib3hDb250aW51ZSI6IuWkjeWItuWujOaIkOWQjuaMiSBFbnRlciDnu6fnu60iLCJJbmJveFVuc3VwcG9ydGVkIjoi5pS25Lu25aS56YeM5Y+R546w5LiN5pSv5oyB55qE5Y6L57yp5YyF77yaezB944CC6K+356e76Zmk"
    "5a6D5Lus77yM5Y+q5L+d55WZIC56aXAg5paH5Lu244CCIiwiSW5ib3hFbXB0eSI6IuWcqCB7MH0g5Lit5rKh5pyJ5om+5YiwIC56aXAg5YyF44CCIiwiSW5ib3hGb3VuZCI6IuWcqOaUtuS7tuWkueS4reaJvuWIsCB7MH0g5Liq5YyF44CCIiwiTWlzc2luZ0NvbmZpZyI6IuayoeacieaJvuWIsOmFjee9ruaWh+S7tuOAguW3suWcqCB7MH0g5Yib5bu656m65qih5p2/44CC6K+35aGr5YaZ55yf5a6e5ri45oiP5ZCN44CBQXBwSUQg5ZKMIERlcG90SUQg5ZCO6YeN5paw6L+Q6KGM5bel5YW344CCIiwiTWlzc2luZ0dhbWVzIjoi6YWN572u5paH5Lu257y65bCR6aG25bGCICdnYW1lcycg5a+56LGh44CC6K+357yW6L6RIHswfeOAgiIsIkdhbWVNaXNzaW5nIjoi5ri45oiPICd7MH0nIOayoeaciemFjee9ruWcqCB7MX0g5Lit44CC6K+35ZyoICdnYW1lcycg5LiL5re75YqgICd7MH0n44CCIiwiUmVsZWFzZU1pc3NpbmciOiLljIUgJ3swfScg5pivezF977yM5L2G6YWN572u5Lit5rKh5pyJICd7MH0uezJ9JyDmrrXjgILor7flhYjooaXlhYUgYXBwSWQg5ZKMIGRlcG90c+OAgiIsIkZ1bGxSZWxlYXNlIjoi5q2j5byP54mIIiwiRGVtb1JlbGVhc2UiOiJEZW1vIOeJiCIsIkFwcElkTWlzc2luZyI6IumFjee9riAnezB9LnsxfScg57y65bCRICdhcHBJZCfjgILor7flhYjooaXlhYUgU3RlYW0gQXBw"
    "SUTjgIIiLCJEZXBvdHNNaXNzaW5nIjoi6YWN572uICd7MH0uezF9JyDnvLrlsJEgJ2RlcG90cyfjgILor7flhYjooaXlhYUgV2luL01hYyBEZXBvdElE44CCIiwiRGVwb3RNaXNzaW5nIjoi5YyFICd7MH0nIOaYryB7MX0g5bmz5Y+w77yM5L2G6YWN572uICd7MH0uezJ9LmRlcG90cy57MX0nIOS4jeWfmOWcqOOAguivt+WFiOihpeWFhSB7MX0gRGVwb3RJROOAgiIsIlBsYWNlaG9sZGVyQ29uZmlnIjoi6YWN572uICd7MH0uezF9JyDnvLrlpLHjgIHkuLrnqbrvvIzmiJbku43mmK/ljaDkvY0gQXBwSUQvRGVwb3RJROOAguivt+WFiOWcqCB7M30g5Lit6KGl5YWoIGFwcElkIOWSjCBkZXBvdHMuezJ944CCIiwiVW5zdXBwb3J0ZWRBcmNoaXZlIjoi5LiN5pSv5oyB55qE5Y6L57yp5YyFICd7MH0n44CC6K+35o+Q5L6b57G75Ly8IFdpbl9HYW1lXzEuMi4zX0RlbW8uemlwIOWRveWQjeeahCAuemlwIOaWh+S7tuOAgiIsIkludmFsaWRGaWxlTmFtZSI6IuaWh+S7tuWQjSAnezB9JyDkuI3nrKblkIjop4TliJnjgILlupTkuLrvvJpXaW5fR2FtZV8xLjIuMy56aXDjgIFNYWNfR2FtZV8xLjIuMy56aXDjgIFXaW5fR2FtZV8xLjIuM19EZW1vLnppcCDmiJYgTWFjX0dhbWVfMS4yLjNfRGVtby56aXDjgIIiLCJEdXBsaWNhdGVQbGF0Zm9ybSI6IuS7u+WKoSAnezF9JyDkuK3ph43lpI3lh7rnjrAgezB9"
    "IOWMheOAgiIsIlJlZnVzZUNsZWFuIjoi5ouS57ud5riF55CG5bel5L2c5Yy65LmL5aSW55qE55uu5b2V77yaezB9IiwiTm9FbnRyeSI6IuWcqCAnezF9JyDkuK3msqHmnInmib7liLAgezB9IOWAmemAieWFpeWPo+OAgiIsIk11bHRpRW50cnkiOiLlnKggJ3swfScg5Lit5om+5Yiw5aSa5Liq5YWl5Y+j5YCZ6YCJ77yaezF944CC6K+35Y+q5L+d55WZ5LiA5Liq44CCIiwiRW50cnlPayI6InswfSDlhaXlj6Plt7Lnu4/mmK8gezF944CCIiwiRW50cnlUYXJnZXRFeGlzdHMiOiLml6Dms5XmioogJ3swfScg5pS55ZCN5Li6ICd7MX0n77yM5Zug5Li655uu5qCH5bey5a2Y5Zyo44CCIiwiRW50cnlSZW5hbWVkIjoiezB9IOWFpeWPo+W3suaUueWQje+8mnsxfSAtPiB7Mn0iLCJFeHRyYWN0aW5nIjoi5q2j5Zyo6Kej5Y6LIHswfSAtPiB7MX0iLCJTdGVhbUNtZE1pc3NpbmciOiLmib7kuI3liLAgU3RlYW1DTUTvvJp7MH3jgILor7fmioogc3RlYW1jbWQuZXhlIOaUvuWIsOi/memHjO+8jOaIlue8lui+kSBjb25maWdcXGdhbWVzLmpzb27jgIIiLCJTdGVhbVVzZXJFbXB0eSI6IlN0ZWFtIOeUqOaIt+WQjeS4uuepuuOAgiIsIlVwbG9hZGluZyI6Iuato+WcqOS4iuS8oCBBcHBJRCB7MH3vvIxTdGVhbUNNRCDot6/lvoTvvJp7MX0iLCJTdGVhbUNtZEZhaWxlZCI6IlN0ZWFtQ01EIOS4iuS8oCBBcHBJ"
    "RCB7MH0g5aSx6LSl77yM6YCA5Ye656CBIHsxfeOAgui+k+WHuuebruW9le+8mnsyfSIsIlN0ZWFtVXNlclByb21wdCI6IlN0ZWFtIOeUqOaIt+WQjSIsIlN0ZWFtVXNlclJlcXVpcmVkIjoi55yf5a6e5LiK5Lyg6ZyA6KaB6L6T5YWlIFN0ZWFtIOeUqOaIt+WQjeOAgiIsIlRhc2tQbGFuIjoi5LiK5Lyg5Lu75Yqh6K6h5YiS77yaIiwiVGFza0xpbmUiOiItIEFwcElEIHswfSB8IHsxfSB8IHsyfSB8IHszfSB8IHs0fSIsIk9wZW5TdGVhbXdvcmtzIjoi546w5Zyo5omT5byA6L+Z5Liq6aG16Z2i5ZCX77yfKFkvTikiLCJQbGFuQ29tcGxldGUiOiLorqHliJLpooTop4jlrozmiJDjgIIiLCJTdGVhbUNtZFBhc3N3b3JkSGludCI6IuWmguaciemcgOimge+8jFN0ZWFtQ01EIOS8mue7p+e7reimgeaxgui+k+WFpeWvhueggeWSjCBTdGVhbSBHdWFyZCDpqozor4HnoIHjgIIiLCJQcmVwYXJpbmciOiLmraPlnKjlh4blpIcgQXBwSUQgezB977yaezF9IHsyfSB7M30iLCJHZW5lcmF0ZWRBcHBWZGYiOiLlt7LnlJ/miJAgYXBwIFZERu+8mnswfSIsIkJ1aWxkRGVzY3JpcHRpb24iOiLmnoTlu7rmj4/ov7DvvJp7MH0iLCJEcnlSdW5Ta2lwcGVkIjoi5bmy6LeR5qih5byP5bey6Lez6L+HIEFwcElEIHswfSDnmoQgU3RlYW1DTUQg5LiK5Lyg44CCIiwiVXBsb2FkRmluaXNoZWQiOiJBcHBJRCB7MH0g5LiK"
    "5Lyg5a6M5oiQ44CC6L6T5Ye655uu5b2V77yaezF9IiwiRG9uZSI6Ij09PT09PT0g5a6M5oiQID09PT09PT0iLCJSZXF1aXJlZEZvcm1hdCI6IuaWh+S7tuWQjeW/hemhu+espuWQiOS7peS4i+agvOW8j++8miJ9"
) -join ""
$zhMessages = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($zhJsonBase64)) | ConvertFrom-Json
$Script:Messages = @{
    "en-US" = @{
        InfoPrefix = "[INFO]"
        WarnPrefix = "[WARN]"
        ErrorPrefix = "[ERROR]"
        Title = "======= Steam Windows Upload Tool ======="
        PlanOnlyMode = "PlanOnly mode: no copy, extract, VDF generation, or upload."
        DryRunMode = "DryRun mode: copy, extract, and VDF generation only; SteamCMD will not run."
        InboxIntro = "Put one or more .zip packages into this folder:"
        InboxOpen = "The folder will open now. Copy the packages there, then return to this window and press Enter."
        InboxOpenFailed = "Could not open folder automatically: {0}"
        InboxContinue = "Press Enter after copying packages"
        InboxUnsupported = "Unsupported archive(s) in inbox: {0}. Please remove them and provide .zip files only."
        InboxEmpty = "No .zip packages found in {0}."
        InboxFound = "Found {0} package(s) in inbox."
        MissingConfig = "Missing config file. A blank template was created at {0}. Please edit it with real game names, AppIDs, and DepotIDs, then run this tool again."
        MissingGames = "Config file is missing the top-level 'games' object. Please edit {0}."
        GameMissing = "Game '{0}' is not configured in {1}. Add a '{0}' entry under 'games'."
        ReleaseMissing = "Package '{0}' is a {1} build, but config has no '{0}.{2}' section. Please add it with appId and depots before uploading."
        FullRelease = "full release"
        DemoRelease = "Demo"
        AppIdMissing = "Config '{0}.{1}' is missing 'appId'. Please add the Steam AppID before uploading."
        DepotsMissing = "Config '{0}.{1}' is missing 'depots'. Please add Win/Mac depot IDs before uploading."
        DepotMissing = "Package '{0}' is for {1}, but config '{0}.{2}.depots.{1}' is missing. Please add the {1} depot ID before uploading."
        PlaceholderConfig = "Config '{0}.{1}' is missing, empty, or still has placeholder AppID/DepotID. Please complete appId and depots.{2} in {3} before uploading."
        UnsupportedArchive = "Unsupported archive '{0}'. Please provide .zip files named like Win_Game_1.2.3_Demo.zip."
        InvalidFileName = "Invalid file name '{0}'. Expected: Win_Game_1.2.3.zip, Mac_Game_1.2.3.zip, Win_Game_1.2.3_Demo.zip, or Mac_Game_1.2.3_Demo.zip."
        DuplicatePlatform = "Duplicate {0} package in task '{1}'."
        RefuseClean = "Refusing to clean outside workspace: {0}"
        NoEntry = "No {0} candidate found in '{1}'."
        MultiEntry = "Multiple entry candidates found in '{0}': {1}. Please keep only one."
        EntryOk = "{0} entry is already {1}."
        EntryTargetExists = "Cannot rename '{0}' to '{1}' because target already exists."
        EntryRenamed = "{0} entry renamed: {1} -> {2}"
        Extracting = "Extracting {0} -> {1}"
        SteamCmdMissing = "SteamCMD not found: {0}. Put steamcmd.exe there or edit config\games.json."
        SteamUserEmpty = "Steam user is empty."
        Uploading = "Uploading AppID {0} with {1}"
        SteamCmdFailed = "SteamCMD failed for AppID {0} with exit code {1}. Output: {2}"
        SteamUserPrompt = "Steam username"
        SteamUserRequired = "Steam username is required for real uploads."
        TaskPlan = "Upload task plan:"
        TaskLine = "- AppID {0} | {1} | {2} | {3} | {4}"
        OpenSteamworks = "Open this page now? (Y/N)"
        PlanComplete = "Plan complete."
        SteamCmdPasswordHint = "SteamCMD will ask for password and Steam Guard code if needed."
        Preparing = "Preparing AppID {0}: {1} {2} {3}"
        GeneratedAppVdf = "Generated app VDF: {0}"
        BuildDescription = "Build description: {0}"
        DryRunSkipped = "DryRun skipped SteamCMD for AppID {0}."
        UploadFinished = "Upload finished for AppID {0}. Output: {1}"
        Done = "======= Done ======="
        RequiredFormat = "Required file name format:"
    }
    "zh-CN" = $zhMessages
}
function T {
    param(
        [string]$Key,
        [object[]]$Values = @()
    )

    $pack = $Script:Messages[$Language]
    if ($pack -is [hashtable]) {
        $text = $pack[$Key]
    } else {
        $text = $pack.PSObject.Properties[$Key].Value
    }
    if ($Values.Count -gt 0) {
        return [string]::Format($text, $Values)
    }
    return $text
}

function D {
    param([string]$Base64)
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64))
}

function Get-LocalizedText {
    param(
        [string]$English,
        [string]$ChineseBase64
    )

    if ($Language -eq "zh-CN") {
        return D $ChineseBase64
    }
    return $English
}

function Test-FolderAlreadyOpen {
    param([string]$Path)

    try {
        $target = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
        $shell = New-Object -ComObject Shell.Application
        foreach ($window in @($shell.Windows())) {
            $locationUrl = [string]$window.LocationURL
            if ([string]::IsNullOrWhiteSpace($locationUrl)) {
                continue
            }

            $windowPath = [System.Uri]::UnescapeDataString((New-Object System.Uri($locationUrl)).LocalPath).TrimEnd('\')
            if ([string]::Equals($windowPath, $target, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}

function Write-Info {
    param([string]$Message)
    $prefix = & T -Key "InfoPrefix"
    Write-Host "$prefix $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    $prefix = & T -Key "WarnPrefix"
    Write-Host "$prefix $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    $prefix = & T -Key "ErrorPrefix"
    Write-Host "$prefix $Message" -ForegroundColor Red
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
        if ($paths.Count -eq 0) {
            throw (Get-LocalizedText -English "No valid package path was provided. Put zip files into Win/inbox, or pass zip files with -PackagePath." -ChineseBase64 "5rKh5pyJ5o+Q5L6b5pyJ5pWI55qE5YyF6Lev5b6E44CC6K+35oqKIHppcCDmlL7lhaUgV2luL2luYm9477yM5oiW6YCa6L+HIC1QYWNrYWdlUGF0aCDmjIflrpogemlwIOaWh+S7tuOAgg==")
        }
        return $paths.ToArray()
    }

    return Get-InboxPackagePaths
}

function Get-InboxPackagePaths {
    New-Item -ItemType Directory -Path $Script:Inbox -Force | Out-Null

    Write-Host ""
    Write-Host $(& T -Key "InboxIntro")
    Write-Host "  $Script:Inbox" -ForegroundColor Yellow
    Write-Host ""
    Write-Host $(& T -Key "InboxOpen")

    if (-not (Test-FolderAlreadyOpen -Path $Script:Inbox)) {
        try {
            Start-Process explorer.exe -ArgumentList "`"$Script:Inbox`""
        }
        catch {
            Write-Warn $(& T -Key "InboxOpenFailed" -Values @($_.Exception.Message))
        }
    }

    while ($true) {
        $null = Read-Host $(& T -Key "InboxContinue")

        $files = @(Get-ChildItem -LiteralPath $Script:Inbox -File | Sort-Object Name)
        $archives = @($files | Where-Object { $_.Extension -ieq ".zip" })
        $unsupported = @($files | Where-Object { $_.Extension -in @(".rar", ".7z") })
        $badNames = @($archives | Where-Object { -not [regex]::Match($_.Name, $Script:NamePattern).Success })

        if ($unsupported.Count -gt 0) {
            Write-Err (Get-LocalizedText -English "Unsupported archive format:" -ChineseBase64 "5Lul5LiL5Y6L57yp5YyF5qC85byP5LiN5pSv5oyB77ya")
            $unsupported | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Yellow }
        }

        if ($badNames.Count -gt 0) {
            Write-Err (Get-LocalizedText -English "Invalid file name(s):" -ChineseBase64 "5Lul5LiL5paH5Lu25ZCN5LiN56ym5ZCI6KeE5YiZ77ya")
            $badNames | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Yellow }
            Write-Host ""
            Write-Host $(& T -Key "RequiredFormat")
            Write-Host "  Win_GameName_1.2.3.zip"
            Write-Host "  Mac_GameName_1.2.3.zip"
            Write-Host "  Win_GameName_1.2.3_Demo.zip"
            Write-Host "  Mac_GameName_1.2.3_Demo.zip"
        }

        if ($archives.Count -eq 0) {
            Write-Warn (Get-LocalizedText -English "No .zip packages found. Copy packages there, then press Enter to scan again." -ChineseBase64 "5pyq5om+5YiwIC56aXAg5YyF44CC6K+35aSN5Yi25YyF5L2T5ZCO5oyJIEVudGVyIOmHjeaWsOaJq+aPj+OAgg==")
            continue
        }

        if ($unsupported.Count -gt 0 -or $badNames.Count -gt 0) {
            Write-Warn (Get-LocalizedText -English "Fix or remove the files above so every zip follows the required naming rule, then press Enter to scan again." -ChineseBase64 "6K+35L+u5pS5L+enu+mZpOS4iui/sOaWh+S7tu+8jOehruS/neaJgOaciSB6aXAg5paH5Lu26YO956ym5ZCI5ZG95ZCN6KeE5YiZ77yM54S25ZCO5oyJIEVudGVyIOmHjeaWsOaJq+aPj+OAgg==")
            continue
        }

        Write-Info $(& T -Key "InboxFound" -Values @($archives.Count))
        return @($archives | ForEach-Object { $_.FullName })
    }
}

function Load-Config {
    if (-not (Test-Path -LiteralPath $Script:ConfigPath)) {
        New-EmptyConfig -Path $Script:ConfigPath
        throw $(& T -Key "MissingConfig" -Values @($Script:ConfigPath))
    }

    $raw = Get-Content -LiteralPath $Script:ConfigPath -Raw -Encoding UTF8
    return $raw | ConvertFrom-Json
}

function Load-ConfigWithRetry {
    while ($true) {
        try {
            return Load-Config
        }
        catch {
            if (-not $Script:InteractiveMode) {
                throw
            }

            Write-Err $_.Exception.Message
            Write-Warn (Get-LocalizedText -English "Fix the config, then press Enter to reload it." -ChineseBase64 "6K+35L+u5pS56YWN572u5ZCO5oyJIEVudGVyIOmHjeaWsOivu+WPluOAgg==")
            $null = Read-Host
        }
    }
}

function New-EmptyConfig {
    param([string]$Path)

    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $template = [ordered]@{
        setLive = ""
        steamCmdPath = "builder\steamcmd.exe"
        games = [ordered]@{
            YourGameName = [ordered]@{
                full = [ordered]@{
                    appId = ""
                    depots = [ordered]@{
                        Win = ""
                        Mac = ""
                    }
                }
                demo = [ordered]@{
                    appId = ""
                    depots = [ordered]@{
                        Win = ""
                        Mac = ""
                    }
                }
            }
        }
    }

    $template | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Test-Placeholder {
    param([string]$Value)
    return [string]::IsNullOrWhiteSpace($Value) -or $Value -like "TODO*"
}

function Test-JsonProperty {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $false }
    return $Object.PSObject.Properties.Name.Contains($Name)
}

function Resolve-GameConfig {
    param(
        [object]$Config,
        [string]$Game,
        [bool]$IsDemo,
        [string]$Platform
    )

    if (-not (Test-JsonProperty -Object $Config -Name "games")) {
        throw $(& T -Key "MissingGames" -Values @($Script:ConfigPath))
    }

    if (-not (Test-JsonProperty -Object $Config.games -Name $Game)) {
        throw $(& T -Key "GameMissing" -Values @($Game, $Script:ConfigPath))
    }

    $releaseKey = if ($IsDemo) { "demo" } else { "full" }
    $releaseLabel = if ($IsDemo) { T -Key "DemoRelease" } else { T -Key "FullRelease" }
    $gameConfig = $Config.games.$Game
    if (-not (Test-JsonProperty -Object $gameConfig -Name $releaseKey)) {
        throw $(& T -Key "ReleaseMissing" -Values @($Game, $releaseLabel, $releaseKey))
    }

    $releaseConfig = $gameConfig.$releaseKey
    if (-not (Test-JsonProperty -Object $releaseConfig -Name "appId")) {
        throw $(& T -Key "AppIdMissing" -Values @($Game, $releaseKey))
    }
    if (-not (Test-JsonProperty -Object $releaseConfig -Name "depots")) {
        throw $(& T -Key "DepotsMissing" -Values @($Game, $releaseKey))
    }
    if (-not (Test-JsonProperty -Object $releaseConfig.depots -Name $Platform)) {
        throw $(& T -Key "DepotMissing" -Values @($Game, $Platform, $releaseKey))
    }

    $appId = [string]$releaseConfig.appId
    $depotId = [string]$releaseConfig.depots.$Platform
    if ((Test-Placeholder $appId) -or (Test-Placeholder $depotId)) {
        if (-not $AllowPlaceholderConfig) {
            throw $(& T -Key "PlaceholderConfig" -Values @($Game, $releaseKey, $Platform, $Script:ConfigPath))
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

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw (Get-LocalizedText -English "Package path is empty. Make sure the file exists, or copy it into Win/inbox and scan again." -ChineseBase64 "5YyF6Lev5b6E5Li656m644CC6K+356Gu6K6k5paH5Lu25a2Y5Zyo77yM5oiW6YeN5paw5aSN5Yi25YiwIFdpbi9pbmJveCDlkI7lho3miavmj4/jgII=")
    }

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $file = Get-Item -LiteralPath $resolved.Path

    if ($file.Extension -ieq ".rar") {
        throw $(& T -Key "UnsupportedArchive" -Values @($file.Name))
    }

    $match = [regex]::Match($file.Name, $Script:NamePattern)
    if (-not $match.Success) {
        throw $(& T -Key "InvalidFileName" -Values @($file.Name))
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

function Resolve-PackagesWithRetry {
    param(
        [string[]]$Paths,
        [object]$Config
    )

    while ($true) {
        $packages = @()
        $errors = @()

        foreach ($path in $Paths) {
            try {
                $packages += Parse-Package -Path $path -Config $Config
            }
            catch {
                $errors += [pscustomobject]@{
                    Path = $path
                    Message = $_.Exception.Message
                }
            }
        }

        if ($errors.Count -eq 0) {
            return [pscustomobject]@{
                Packages = $packages
                Config = $Config
            }
        }

        if (-not $Script:InteractiveMode) {
            $message = ($errors | ForEach-Object { "$($_.Path): $($_.Message)" }) -join [Environment]::NewLine
            throw $message
        }

        Write-Err (Get-LocalizedText -English "Config or package validation still has problems:" -ChineseBase64 "6YWN572u5oiW5YyF5paH5Lu25LuN5pyJ6Zeu6aKY77ya")
        foreach ($err in $errors) {
            Write-Host "  $($err.Path)" -ForegroundColor Yellow
            Write-Host "    $($err.Message)" -ForegroundColor Yellow
        }
        Write-Warn (Get-LocalizedText -English "Fix the issues above, then press Enter to check again." -ChineseBase64 "6K+35L+u5aSN5LiK6L+w6Zeu6aKY5ZCO5oyJIEVudGVyIOmHjeaWsOajgOafpeOAgg==")
        $null = Read-Host
        $Config = Load-ConfigWithRetry
        $Paths = Get-InboxPackagePaths
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
            throw $(& T -Key "DuplicatePlatform" -Values @($pkg.Platform, $key))
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
        throw $(& T -Key "RefuseClean" -Values @($Path))
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
        $candidates = @(Get-ChildItem -LiteralPath $root -Force -File -Filter "*.exe" |
            Where-Object { $_.Name -notlike "UnityCrashHandler*.exe" -and $_.Name -notlike "crashhandler*.exe" })
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
        throw $(& T -Key "NoEntry" -Values @($targetName, $root))
    }
    if ($candidates.Count -gt 1) {
        $names = ($candidates | ForEach-Object { $_.Name }) -join ", "
        throw $(& T -Key "MultiEntry" -Values @($root, $names))
    }

    $entry = $candidates[0]
    if ($entry.Name -eq $targetName) {
        Write-Info $(& T -Key "EntryOk" -Values @($Platform, $targetName))
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
        throw $(& T -Key "EntryTargetExists" -Values @($entry.Name, $targetName))
    }

    Rename-Item -LiteralPath $entry.FullName -NewName $targetName
    Write-Warn $(& T -Key "EntryRenamed" -Values @($Platform, $entry.Name, $targetName))
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

    Write-Info $(& T -Key "Extracting" -Values @($Package.FileName, $contentDir))
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
        [object]$Config,
        [string]$SteamUser
    )

    $steamCmdPath = [string]$Config.steamCmdPath
    if ([string]::IsNullOrWhiteSpace($steamCmdPath)) {
        $steamCmdPath = "builder\steamcmd.exe"
    }
    if (-not [System.IO.Path]::IsPathRooted($steamCmdPath)) {
        $steamCmdPath = Join-Path $Script:Root $steamCmdPath
    }

    if (-not (Test-Path -LiteralPath $steamCmdPath)) {
        throw $(& T -Key "SteamCmdMissing" -Values @($steamCmdPath))
    }

    if ([string]::IsNullOrWhiteSpace($SteamUser)) {
        throw $(& T -Key "SteamUserEmpty")
    }

    Write-Info $(& T -Key "Uploading" -Values @($Task.AppId, $steamCmdPath))
    & $steamCmdPath +login $SteamUser +run_app_build $VdfInfo.AppVdf +quit
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw $(& T -Key "SteamCmdFailed" -Values @($Task.AppId, $exitCode, $VdfInfo.OutputDir))
    }
}

function Get-SteamUser {
    param([string]$ProvidedSteamUser)

    if (-not [string]::IsNullOrWhiteSpace($ProvidedSteamUser)) {
        return $ProvidedSteamUser.Trim()
    }

    Write-Host ""
    $user = Read-Host $(& T -Key "SteamUserPrompt")
    if ([string]::IsNullOrWhiteSpace($user)) {
        throw $(& T -Key "SteamUserRequired")
    }
    return $user.Trim()
}

function Show-Plan {
    param([object[]]$Tasks)

    Write-Host ""
    Write-Host $(& T -Key "TaskPlan")
    foreach ($task in $Tasks) {
        $platforms = ($task.Packages | Sort-Object Platform | ForEach-Object { "$($_.Platform):Depot $($_.DepotId)" }) -join ", "
        Write-Host $(& T -Key "TaskLine" -Values @($task.AppId, $task.Game, $task.Version, $task.ReleaseKey, $platforms))
    }
}

function Prompt-OpenSteamworks {
    param([object[]]$SucceededTasks)

    if ($SucceededTasks.Count -eq 0) { return }

    Write-Host ""
    foreach ($task in $SucceededTasks) {
        $url = "https://partner.steamgames.com/apps/builds/$($task.AppId)"
        Write-Host "Steamworks: $url"
        $answer = Read-Host $(& T -Key "OpenSteamworks")
        if ($answer -match '^(y|yes)$') {
            Start-Process $url
        }
    }
}

try {
    Write-Host $(& T -Key "Title") -ForegroundColor Green
    if ($PlanOnly) { Write-Warn $(& T -Key "PlanOnlyMode") }
    elseif ($DryRun) { Write-Warn $(& T -Key "DryRunMode") }

    $config = Load-ConfigWithRetry
    $paths = Get-PackagePaths
    $validation = Resolve-PackagesWithRetry -Paths $paths -Config $config
    $packages = $validation.Packages
    $config = $validation.Config

    Write-Host ""
    if ($Language -eq "zh-CN") {
        $packages | Sort-Object Game, ReleaseKey, Version, Platform |
            Select-Object @{Name=(D "5bmz5Y+w"); Expression={$_.Platform}},
                          @{Name=(D "5ri45oiP"); Expression={$_.Game}},
                          @{Name=(D "54mI5pys"); Expression={$_.Version}},
                          @{Name=(D "57G75Z6L"); Expression={$_.ReleaseKey}},
                          @{Name="AppID"; Expression={$_.AppId}},
                          @{Name="DepotID"; Expression={$_.DepotId}},
                          @{Name=(D "5paH5Lu25ZCN"); Expression={$_.FileName}} |
            Format-Table -AutoSize
    } else {
        $packages | Sort-Object Game, ReleaseKey, Version, Platform |
            Format-Table Platform, Game, Version, ReleaseKey, AppId, DepotId, FileName -AutoSize
    }

    $tasks = Group-Packages -Packages $packages
    Show-Plan -Tasks $tasks

    if ($PlanOnly) {
        Write-Info $(& T -Key "PlanComplete")
        exit 0
    }

    $uploadSteamUser = $null
    if (-not $DryRun) {
        $uploadSteamUser = Get-SteamUser -ProvidedSteamUser $SteamUser
        Write-Warn $(& T -Key "SteamCmdPasswordHint")
    }

    $succeeded = @()
    $failed = @()
    foreach ($task in $tasks) {
        Write-Host ""
        Write-Info $(& T -Key "Preparing" -Values @($task.AppId, $task.Game, $task.Version, $task.ReleaseKey))
        try {
            $prepared = @()
            foreach ($pkg in $task.Packages) {
                try {
                    $prepared += Expand-Package -Package $pkg
                }
                catch {
                    $failed += [pscustomobject]@{
                        Task = "$($task.Game) $($task.Version) $($task.ReleaseKey)"
                        Reason = (Get-LocalizedText -English "Package preparation failed. Rework this file and run it again: {0}" -ChineseBase64 "5YyF5L2T5YeG5aSH5aSx6LSl77yM5ZCO57ut6K+36YeN5paw5aSE55CG6L+Z5Liq5paH5Lu277yaezB9") -f $pkg.FileName
                        Detail = $_.Exception.Message
                    }
                    throw
                }
            }

            $vdfInfo = New-VdfFiles -Task $task -PreparedPackages $prepared -Config $config
            Write-Info $(& T -Key "GeneratedAppVdf" -Values @($vdfInfo.AppVdf))
            Write-Info $(& T -Key "BuildDescription" -Values @($vdfInfo.Description))

            if ($DryRun) {
                Write-Warn $(& T -Key "DryRunSkipped" -Values @($task.AppId))
                $succeeded += $task
                continue
            }

            try {
                Invoke-SteamUpload -Task $task -VdfInfo $vdfInfo -Config $config -SteamUser $uploadSteamUser
                Write-Info $(& T -Key "UploadFinished" -Values @($task.AppId, $vdfInfo.OutputDir))
                $succeeded += $task
            }
            catch {
                $failed += [pscustomobject]@{
                    Task = "$($task.Game) $($task.Version) $($task.ReleaseKey)"
                    Reason = Get-LocalizedText -English "Upload failed. Re-run this task later." -ChineseBase64 "5LiK5Lyg5aSx6LSl77yM5ZCO57ut6K+36YeN5paw5pON5L2c6L+Z5Liq5Lu75Yqh44CC"
                    Detail = $_.Exception.Message
                }
                Write-Err $_.Exception.Message
                continue
            }
        }
        catch {
            Write-Err $_.Exception.Message
            continue
        }
    }

    Prompt-OpenSteamworks -SucceededTasks $succeeded
    if ($failed.Count -gt 0) {
        Write-Host ""
        Write-Warn (Get-LocalizedText -English "The following tasks failed; other tasks were still processed:" -ChineseBase64 "5Lul5LiL5Lu75Yqh5aSx6LSl77yM5YW25LuW5Lu75Yqh5bey57un57ut5aSE55CG77ya")
        foreach ($item in $failed) {
            Write-Host ((Get-LocalizedText -English "Failed: {0} | {1}" -ChineseBase64 "5aSx6LSl77yaezB9IHwgezF9") -f $item.Task, $item.Reason) -ForegroundColor Yellow
            Write-Host "  $($item.Detail)" -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host $(& T -Key "Done") -ForegroundColor Green
}
catch {
    Write-Err $_.Exception.Message
    Write-Host ""
    Write-Host $(& T -Key "RequiredFormat")
    Write-Host "  Win_GameName_1.2.3.zip"
    Write-Host "  Mac_GameName_1.2.3.zip"
    Write-Host "  Win_GameName_1.2.3_Demo.zip"
    Write-Host "  Mac_GameName_1.2.3_Demo.zip"
    exit 1
}




