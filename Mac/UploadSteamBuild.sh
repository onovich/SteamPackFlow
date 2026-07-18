#!/bin/bash

# SteamPackFlow macOS uploader.
# This is the macOS translation of Win/UploadSteamBuild.ps1.  Keep the
# workflow and generated workspace/VDF layout in sync with the Windows tool.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
ROOT="$SCRIPT_DIR"
CONFIG_PATH="$ROOT/config/games.json"
WORKSPACE="$ROOT/workspace"
INBOX="$ROOT/inbox"
LANGUAGE="zh-CN"
PLAN_ONLY=false
DRY_RUN=false
ALLOW_PLACEHOLDER_CONFIG=false
INTERACTIVE_MODE=true
STEAM_USER=""
JQ_BIN=""
LAST_ERROR=""
STEAM_CMD_PATH=""
STEAMCMD_MAC_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz"
SHOW_FORMAT_HINT=true

PACKAGE_ARGS=()
SELECTED_PATHS=()
PKG_SOURCE=()
PKG_FILE=()
PKG_PLATFORM=()
PKG_GAME=()
PKG_VERSION=()
PKG_RELEASE=()
PKG_APP_ID=()
PKG_DEPOT_ID=()
PKG_TARGET_ENTRY=()
PKG_TARGET_STEM=()

TASK_KEYS=()
TASK_INDEXES=()
FAILED_TASKS=()
FAILED_REASONS=()
FAILED_DETAILS=()
SUCCESS_APP_IDS=()

msg() {
    local key="$1"
    shift || true

    if [[ "$LANGUAGE" == "zh-CN" ]]; then
        case "$key" in
            InfoPrefix) printf '%s' '[信息]' ;;
            WarnPrefix) printf '%s' '[警告]' ;;
            ErrorPrefix) printf '%s' '[错误]' ;;
            Title) printf '%s' '======= Steam macOS 上传工具 =======' ;;
            PlanOnlyMode) printf '%s' 'PlanOnly 模式：不会复制、解压、生成 VDF 或上传。' ;;
            DryRunMode) printf '%s' 'DryRun 模式：会复制、解压并生成 VDF，但不会运行 SteamCMD。' ;;
            DependencyMissing) printf '缺少依赖：%s。请先安装后再运行。' "${1-}" ;;
            InboxIntro) printf '%s' '请把一个或多个 .zip 压缩包放入此目录：' ;;
            InboxOpen) printf '%s' '现在会打开该目录。复制压缩包后回到此窗口并按 Enter。' ;;
            InboxOpenFailed) printf '无法自动打开目录：%s' "${1-}" ;;
            InboxContinue) printf '%s' '复制完成后按 Enter' ;;
            InboxUnsupported) printf '收件箱中有不支持的压缩包：%s。请移除它们，只保留 .zip。' "${1-}" ;;
            InboxEmpty) printf '目录 %s 中没有找到 .zip 压缩包。' "${1-}" ;;
            InboxFound) printf '在收件箱中找到 %s 个压缩包。' "${1-}" ;;
            MissingConfig) printf '缺少配置文件。已创建空模板：%s。请填入真实游戏名、AppID 和 DepotID 后重新运行。' "${1-}" ;;
            InvalidConfig) printf '配置文件无法读取或不是有效 JSON：%s。' "${1-}" ;;
            MissingGames) printf '配置文件缺少顶层 games 对象：%s。' "${1-}" ;;
            GameMissing) printf '游戏“%s”未配置在 %s 中，请在 games 下添加它。' "${1-}" "${2-}" ;;
            ReleaseMissing) printf '压缩包“%s”是 %s，但配置没有 %s.%s。上传前请补充 appId 和 depots。' "${1-}" "${2-}" "${1-}" "${3-}" ;;
            FullRelease) printf '%s' '完整发行版' ;;
            DemoRelease) printf '%s' 'Demo' ;;
            AppIdMissing) printf '配置“%s.%s”缺少 appId。' "${1-}" "${2-}" ;;
            DepotsMissing) printf '配置“%s.%s”缺少 depots。' "${1-}" "${2-}" ;;
            EntryNamesMissing) printf '配置“%s.%s”缺少或为空 entryNames.%s，请在 %s 中补全入口名称。' "${1-}" "${2-}" "${3-}" "$CONFIG_PATH" ;;
            DepotMissing) printf '压缩包“%s”是 %s，但配置“%s.%s.depots.%s”缺少 DepotID。' "${1-}" "${2-}" "${1-}" "${3-}" "${2-}" ;;
            PlaceholderConfig) printf '配置“%s.%s”缺少或仍是占位 AppID/DepotID。请在 %s 中补全 appId 和 depots.%s。' "${1-}" "${2-}" "$CONFIG_PATH" "${3-}" ;;
            UnsupportedArchive) printf '不支持的压缩包“%s”，请提供类似 Mac_Game_1.2.3_Demo.zip 的 .zip 文件。' "${1-}" ;;
            InvalidFileName) printf '文件名“%s”无效。格式应为 Win_Game_1.2.3.zip、Mac_Game_1.2.3.zip，或带 _Demo。' "${1-}" ;;
            DuplicatePlatform) printf '任务“%s”中出现重复的 %s 压缩包。' "${2-}" "${1-}" ;;
            RefuseClean) printf '拒绝清理 workspace 外部目录：%s' "${1-}" ;;
            NoEntry) printf '在“%s”中没有找到匹配“%s”的可执行文件或 app 包。请从项目根目录打包。' "${2-}" "${1-}" ;;
            MultiEntry) printf '在“%s”中找到多个入口：%s。请只保留一个。' "${1-}" "${2-}" ;;
            EntryOk) printf '%s 入口已经是 %s。' "${1-}" "${2-}" ;;
            EntryTargetExists) printf '无法将“%s”重命名为“%s”，因为目标已存在。' "${1-}" "${2-}" ;;
            EntryRenamed) printf '%s 入口已重命名：%s -> %s' "${1-}" "${2-}" "${3-}" ;;
            TargetEntry) printf '配置中的目标入口：%s' "${1-}" ;;
            Extracting) printf '正在解压 %s -> %s' "${1-}" "${2-}" ;;
            SteamCmdMissing) printf '找不到 SteamCMD：%s。请将 steamcmd.sh 放到该位置，或修改 config/games.json。' "${1-}" ;;
            SteamCmdDownloading) printf '正在下载并安装 macOS SteamCMD 到 %s' "${1-}" ;;
            SteamCmdInstallFailed) printf 'SteamCMD 安装失败。你也可以手动执行：%s' "${1-}" ;;
            SteamCmdReady) printf 'SteamCMD 已准备好：%s' "${1-}" ;;
            RosettaHint) printf '%s' '当前是 Apple Silicon；如果 SteamCMD 无法启动，请先安装 Rosetta 2：softwareupdate --install-rosetta --agree-to-license' ;;
            SteamUserEmpty) printf '%s' 'Steam 用户名为空。' ;;
            Uploading) printf '正在上传 AppID %s，使用 %s' "${1-}" "${2-}" ;;
            SteamCmdFailed) printf 'AppID %s 的 SteamCMD 失败，退出码 %s。输出目录：%s' "${1-}" "${2-}" "${3-}" ;;
            SteamCmdAttempt) printf 'SteamCMD 登录/上传尝试 #%s' "${1-}" ;;
            SteamPasswordRetry) printf '%s' 'SteamCMD 判定密码无效。请按 Enter 重试并重新输入密码；输入 q 取消。' ;;
            SteamGuardRetry) printf '%s' 'Steam Guard 二次验证未通过。请按 Enter 重试并重新输入新的验证码；输入 q 取消。' ;;
            SteamLoginRetryPrompt) printf '%s' '按 Enter 重试，或输入 q 取消' ;;
            SteamUserPrompt) printf '%s' 'Steam 用户名' ;;
            SteamUserRequired) printf '%s' '真实上传必须提供 Steam 用户名。' ;;
            TaskPlan) printf '%s' '上传任务计划：' ;;
            TaskLine) printf -- '- AppID %s | %s | %s | %s | %s' "${1-}" "${2-}" "${3-}" "${4-}" "${5-}" ;;
            OpenSteamworks) printf '%s' '现在打开 Steamworks 页面吗？(Y/N)' ;;
            PlanComplete) printf '%s' '计划完成。' ;;
            PasswordHint) printf '%s' '如有需要，SteamCMD 会在终端中询问密码和 Steam Guard 验证码。' ;;
            Preparing) printf '准备 AppID %s：%s %s %s' "${1-}" "${2-}" "${3-}" "${4-}" ;;
            GeneratedAppVdf) printf '已生成 app VDF：%s' "${1-}" ;;
            BuildDescription) printf '构建描述：%s' "${1-}" ;;
            DryRunSkipped) printf 'DryRun 已跳过 AppID %s 的 SteamCMD 上传。' "${1-}" ;;
            UploadFinished) printf 'AppID %s 上传完成。输出目录：%s' "${1-}" "${2-}" ;;
            Done) printf '%s' '======= 完成 =======' ;;
            RequiredFormat) printf '%s' '要求的文件名格式：' ;;
            PackagePathEmpty) printf '%s' '包路径为空，请确认文件存在，或把 zip 放入 Mac/inbox。' ;;
            ConfigReload) printf '%s' '请修正配置后按 Enter 重新加载。' ;;
            ValidationProblems) printf '%s' '配置或压缩包校验仍有问题：' ;;
            FixValidation) printf '%s' '请修正上述问题后按 Enter 再次检查。' ;;
            PackagePreparationFailed) printf '压缩包准备失败，请修复此文件后重新运行：%s' "${1-}" ;;
            UploadFailed) printf '%s' '上传失败，稍后可重新运行此任务。' ;;
            FailedTasks) printf '%s' '以下任务失败，但其他任务仍已继续处理：' ;;
            FailedLine) printf '失败：%s | %s' "${1-}" "${2-}" ;;
            MovedDone) printf '已将上传成功的收件箱压缩包移到 done：%s' "${1-}" ;;
            MoveDoneFailure) printf '上传成功，但无法将收件箱压缩包移到 done：%s。%s' "${1-}" "${2-}" ;;
            DataRenamed) printf '%s 数据目录已重命名：%s -> %s' "${1-}" "${2-}" "${3-}" ;;
            IgnoreCrash) printf '检查 Windows 入口时忽略崩溃处理程序：%s' "${1-}" ;;
            MacExecRenamed) printf 'macOS 可执行文件已重命名：%s -> %s' "${1-}" "${2-}" ;;
            HelperBundleRenamed) printf 'Electron Helper 包已重命名：%s -> %s' "${1-}" "${2-}" ;;
            PlistUpdated) printf '已更新 Info.plist CFBundleExecutable：%s' "${1-}" ;;
            PlistFieldUpdated) printf '已更新 %s：%s' "${1-}" "${2-}" ;;
            NoMacExec) printf '在 %s 中没有找到 macOS 可执行文件。' "${1-}" ;;
            MultiMacExec) printf '在 %s 中找到多个 macOS 可执行文件：%s。请只保留一个。' "${1-}" "${2-}" ;;
            *) printf '%s' "$key" ;;
        esac
    else
        case "$key" in
            InfoPrefix) printf '%s' '[INFO]' ;;
            WarnPrefix) printf '%s' '[WARN]' ;;
            ErrorPrefix) printf '%s' '[ERROR]' ;;
            Title) printf '%s' '======= Steam macOS Upload Tool =======' ;;
            PlanOnlyMode) printf '%s' 'PlanOnly mode: no copy, extract, VDF generation, or upload.' ;;
            DryRunMode) printf '%s' 'DryRun mode: copy, extract, and VDF generation only; SteamCMD will not run.' ;;
            DependencyMissing) printf 'Missing dependency: %s. Install it before running this tool.' "${1-}" ;;
            InboxIntro) printf '%s' 'Put one or more .zip packages into this folder:' ;;
            InboxOpen) printf '%s' 'The folder will open now. Copy the packages there, then return and press Enter.' ;;
            InboxOpenFailed) printf 'Could not open folder automatically: %s' "${1-}" ;;
            InboxContinue) printf '%s' 'Press Enter after copying packages' ;;
            InboxUnsupported) printf 'Unsupported archive(s) in inbox: %s. Remove them and provide .zip files only.' "${1-}" ;;
            InboxEmpty) printf 'No .zip packages found in %s.' "${1-}" ;;
            InboxFound) printf 'Found %s package(s) in inbox.' "${1-}" ;;
            MissingConfig) printf 'Missing config file. A blank template was created at %s. Fill in real game names, AppIDs, and DepotIDs, then run again.' "${1-}" ;;
            InvalidConfig) printf 'Config is unreadable or is not valid JSON: %s.' "${1-}" ;;
            MissingGames) printf "Config is missing the top-level 'games' object: %s." "${1-}" ;;
            GameMissing) printf "Game '%s' is not configured in %s. Add it under 'games'." "${1-}" "${2-}" ;;
            ReleaseMissing) printf "Package '%s' is a %s build, but config has no %s.%s section." "${1-}" "${2-}" "${1-}" "${3-}" ;;
            FullRelease) printf '%s' 'full release' ;;
            DemoRelease) printf '%s' 'Demo' ;;
            AppIdMissing) printf "Config '%s.%s' is missing 'appId'." "${1-}" "${2-}" ;;
            DepotsMissing) printf "Config '%s.%s' is missing 'depots'." "${1-}" "${2-}" ;;
            EntryNamesMissing) printf "Config '%s.%s' is missing or has an empty 'entryNames.%s'. Complete it in %s." "${1-}" "${2-}" "${3-}" "$CONFIG_PATH" ;;
            DepotMissing) printf "Package '%s' is for %s, but config '%s.%s.depots.%s' is missing." "${1-}" "${2-}" "${1-}" "${3-}" "${2-}" ;;
            PlaceholderConfig) printf "Config '%s.%s' is missing, empty, or still has placeholder AppID/DepotID. Complete appId and depots.%s in %s." "${1-}" "${2-}" "${3-}" "$CONFIG_PATH" ;;
            UnsupportedArchive) printf "Unsupported archive '%s'. Provide a .zip named like Mac_Game_1.2.3_Demo.zip." "${1-}" ;;
            InvalidFileName) printf "Invalid file name '%s'. Expected Win_Game_1.2.3.zip, Mac_Game_1.2.3.zip, or a _Demo variant." "${1-}" ;;
            DuplicatePlatform) printf "Duplicate %s package in task '%s'." "${1-}" "${2-}" ;;
            RefuseClean) printf 'Refusing to clean outside workspace: %s' "${1-}" ;;
            NoEntry) printf "No executable or app bundle matching '%s' was found in '%s'. Zip from the project root." "${1-}" "${2-}" ;;
            MultiEntry) printf "Multiple entry candidates found in '%s': %s. Keep only one." "${1-}" "${2-}" ;;
            EntryOk) printf '%s entry is already %s.' "${1-}" "${2-}" ;;
            EntryTargetExists) printf "Cannot rename '%s' to '%s' because the target already exists." "${1-}" "${2-}" ;;
            EntryRenamed) printf '%s entry renamed: %s -> %s' "${1-}" "${2-}" "${3-}" ;;
            TargetEntry) printf 'Target entry from config: %s' "${1-}" ;;
            Extracting) printf 'Extracting %s -> %s' "${1-}" "${2-}" ;;
            SteamCmdMissing) printf 'SteamCMD not found: %s. Put steamcmd.sh there or edit config/games.json.' "${1-}" ;;
            SteamCmdDownloading) printf 'Downloading and installing macOS SteamCMD to %s' "${1-}" ;;
            SteamCmdInstallFailed) printf 'SteamCMD installation failed. You can also run manually: %s' "${1-}" ;;
            SteamCmdReady) printf 'SteamCMD is ready: %s' "${1-}" ;;
            RosettaHint) printf '%s' 'This is Apple Silicon; if SteamCMD cannot start, install Rosetta 2 first: softwareupdate --install-rosetta --agree-to-license' ;;
            SteamUserEmpty) printf '%s' 'Steam user is empty.' ;;
            Uploading) printf 'Uploading AppID %s with %s' "${1-}" "${2-}" ;;
            SteamCmdFailed) printf 'SteamCMD failed for AppID %s with exit code %s. Output directory: %s' "${1-}" "${2-}" "${3-}" ;;
            SteamCmdAttempt) printf 'SteamCMD login/upload attempt #%s' "${1-}" ;;
            SteamPasswordRetry) printf '%s' 'SteamCMD rejected the password. Press Enter to retry and enter it again; type q to cancel.' ;;
            SteamGuardRetry) printf '%s' 'Steam Guard verification failed. Press Enter to retry with a new code; type q to cancel.' ;;
            SteamLoginRetryPrompt) printf '%s' 'Press Enter to retry, or type q to cancel' ;;
            SteamUserPrompt) printf '%s' 'Steam username' ;;
            SteamUserRequired) printf '%s' 'Steam username is required for real uploads.' ;;
            TaskPlan) printf '%s' 'Upload task plan:' ;;
            TaskLine) printf -- '- AppID %s | %s | %s | %s | %s' "${1-}" "${2-}" "${3-}" "${4-}" "${5-}" ;;
            OpenSteamworks) printf '%s' 'Open this page now? (Y/N)' ;;
            PlanComplete) printf '%s' 'Plan complete.' ;;
            PasswordHint) printf '%s' 'SteamCMD will ask for password and Steam Guard code if needed.' ;;
            Preparing) printf 'Preparing AppID %s: %s %s %s' "${1-}" "${2-}" "${3-}" "${4-}" ;;
            GeneratedAppVdf) printf 'Generated app VDF: %s' "${1-}" ;;
            BuildDescription) printf 'Build description: %s' "${1-}" ;;
            DryRunSkipped) printf 'DryRun skipped SteamCMD for AppID %s.' "${1-}" ;;
            UploadFinished) printf 'Upload finished for AppID %s. Output: %s' "${1-}" "${2-}" ;;
            Done) printf '%s' '======= Done =======' ;;
            RequiredFormat) printf '%s' 'Required file name format:' ;;
            PackagePathEmpty) printf '%s' 'Package path is empty. Make sure the file exists, or copy it into Mac/inbox.' ;;
            ConfigReload) printf '%s' 'Fix the config, then press Enter to reload it.' ;;
            ValidationProblems) printf '%s' 'Config or package validation still has problems:' ;;
            FixValidation) printf '%s' 'Fix the issues above, then press Enter to check again.' ;;
            PackagePreparationFailed) printf 'Package preparation failed. Rework this file and run it again: %s' "${1-}" ;;
            UploadFailed) printf '%s' 'Upload failed. Re-run this task later.' ;;
            FailedTasks) printf '%s' 'The following tasks failed; other tasks were still processed:' ;;
            FailedLine) printf 'Failed: %s | %s' "${1-}" "${2-}" ;;
            MovedDone) printf 'Moved uploaded inbox package(s) to done: %s' "${1-}" ;;
            MoveDoneFailure) printf 'Upload succeeded, but failed to move inbox archive to done: %s. %s' "${1-}" "${2-}" ;;
            DataRenamed) printf '%s data directory renamed: %s -> %s' "${1-}" "${2-}" "${3-}" ;;
            IgnoreCrash) printf 'Crash handler executable ignored while checking Windows entry: %s' "${1-}" ;;
            MacExecRenamed) printf 'macOS executable renamed: %s -> %s' "${1-}" "${2-}" ;;
            HelperBundleRenamed) printf 'Electron Helper bundle renamed: %s -> %s' "${1-}" "${2-}" ;;
            PlistUpdated) printf 'Info.plist CFBundleExecutable updated: %s' "${1-}" ;;
            PlistFieldUpdated) printf 'Updated %s: %s' "${1-}" "${2-}" ;;
            NoMacExec) printf 'No macOS executable candidate found in %s.' "${1-}" ;;
            MultiMacExec) printf 'Multiple macOS executable candidates found in %s: %s. Keep only one.' "${1-}" "${2-}" ;;
            *) printf '%s' "$key" ;;
        esac
    fi
}

info() { printf '%s %s\n' "$(msg InfoPrefix)" "$1"; }
warn() { printf '%s %s\n' "$(msg WarnPrefix)" "$1" >&2; }
error() { LAST_ERROR="$1"; printf '%s %s\n' "$(msg ErrorPrefix)" "$1" >&2; }
fail() { LAST_ERROR="$1"; error "$1"; return 1; }

usage() {
    cat <<'EOF'
Usage: UploadSteamBuild.sh [options] [zip ...]

Options:
  --package-path PATH       Add a package path; repeatable and comma-separated.
  --steam-user USER         Steam username for real uploads.
  --config PATH             Use a different games.json.
  --language zh-CN|en-US    Select console language (default: zh-CN).
  --plan-only               Validate and print the upload plan only.
  --dry-run                 Prepare content and VDF files without SteamCMD.
  --allow-placeholder-config
                            Allow TODO/empty AppID and DepotID values.
  -h, --help                Show this help.

PowerShell-style aliases (-PackagePath, -SteamUser, -ConfigPath, -Language,
-PlanOnly, -DryRun, -AllowPlaceholderConfig) are also accepted for easier
cross-platform migration.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --package-path|-PackagePath)
                [[ $# -ge 2 ]] || { error 'Missing value for package path.'; return 1; }
                PACKAGE_ARGS+=("$2"); shift 2 ;;
            --package-path=*) PACKAGE_ARGS+=("${1#*=}"); shift ;;
            --steam-user|-SteamUser)
                [[ $# -ge 2 ]] || { error 'Missing value for Steam username.'; return 1; }
                STEAM_USER="$2"; shift 2 ;;
            --config|-ConfigPath)
                [[ $# -ge 2 ]] || { error 'Missing value for config path.'; return 1; }
                CONFIG_PATH="$2"; shift 2 ;;
            --language|-Language)
                [[ $# -ge 2 ]] || { error 'Missing value for language.'; return 1; }
                LANGUAGE="$2"; shift 2 ;;
            --plan-only|-PlanOnly) PLAN_ONLY=true; shift ;;
            --dry-run|-DryRun) DRY_RUN=true; shift ;;
            --allow-placeholder-config|-AllowPlaceholderConfig) ALLOW_PLACEHOLDER_CONFIG=true; shift ;;
            -h|--help) usage; exit 0 ;;
            --) shift; while [[ $# -gt 0 ]]; do PACKAGE_ARGS+=("$1"); shift; done ;;
            -*) error "Unknown option: $1"; return 1 ;;
            *) PACKAGE_ARGS+=("$1"); shift ;;
        esac
    done

    if [[ "$LANGUAGE" != "zh-CN" && "$LANGUAGE" != "en-US" ]]; then
        error 'Language must be zh-CN or en-US.'
        return 1
    fi
    [[ ${#PACKAGE_ARGS[@]} -eq 0 ]] && INTERACTIVE_MODE=true || INTERACTIVE_MODE=false
    return 0
}

require_dependencies() {
    if ! JQ_BIN="$(command -v jq 2>/dev/null)" || [[ -z "$JQ_BIN" ]]; then
        error "$(msg DependencyMissing jq)"
        return 1
    fi
    if ! command -v unzip >/dev/null 2>&1; then
        error "$(msg DependencyMissing unzip)"
        return 1
    fi
    if ! command -v plutil >/dev/null 2>&1; then
        error "$(msg DependencyMissing plutil)"
        return 1
    fi
    return 0
}

create_empty_config() {
    local dir
    dir="$(dirname "$CONFIG_PATH")"
    mkdir -p "$dir" || return 1
    printf '%s\n' '{
  "setLive": "",
  "steamCmdPath": "builder/steamcmd.sh",
  "games": {
    "YourGameName": {
      "full": {
        "entryNames": { "Win": "", "Mac": "" },
        "appId": "",
        "depots": { "Win": "", "Mac": "" }
      },
      "demo": {
        "entryNames": { "Win": "", "Mac": "" },
        "appId": "",
        "depots": { "Win": "", "Mac": "" }
      }
    }
  }
}' > "$CONFIG_PATH"
}

ensure_config_schema() {
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/steampackflow-config.XXXXXX")" || return 1
    if ! "$JQ_BIN" '
      def ensure_release($legacy):
        (. // {})
        | .appId = (.appId // "")
        | .entryNames = (if (.entryNames | type) == "object" then .entryNames else {} end)
        | .entryNames.Win = (.entryNames.Win // $legacy.Win // "")
        | .entryNames.Mac = (.entryNames.Mac // $legacy.Mac // "")
        | .depots = (if (.depots | type) == "object" then .depots else {} end)
        | .depots.Win = (.depots.Win // "")
        | .depots.Mac = (.depots.Mac // "");
      . as $root
      | (if ($root | type) == "object" then $root else {} end)
      | .setLive = (.setLive // "")
      | .steamCmdPath = (.steamCmdPath // "builder/steamcmd.sh")
      | .games = (if (.games | type) == "object" then .games else {} end)
      | .games |= with_entries(
          .value = (if (.value | type) == "object" then .value else {} end)
          | (.value.entryNames // {}) as $legacy
          | .value.full = ((.value.full // {}) | ensure_release($legacy))
          | .value.demo = ((.value.demo // {}) | ensure_release($legacy))
          | .value |= del(.entryNames)
        )
    ' "$CONFIG_PATH" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    if ! cmp -s "$tmp" "$CONFIG_PATH"; then
        if ! mv "$tmp" "$CONFIG_PATH"; then
            rm -f "$tmp"
            return 1
        fi
        warn 'Config schema updated with missing empty fields.'
    else
        rm -f "$tmp"
    fi
    return 0
}

load_config() {
    if [[ ! -f "$CONFIG_PATH" ]]; then
        if ! create_empty_config; then
            error "$(msg InvalidConfig "$CONFIG_PATH")"
            return 1
        fi
        error "$(msg MissingConfig "$CONFIG_PATH")"
        return 1
    fi
    if ! "$JQ_BIN" empty "$CONFIG_PATH" >/dev/null 2>&1; then
        error "$(msg InvalidConfig "$CONFIG_PATH")"
        return 1
    fi
    if ! ensure_config_schema; then
        error "$(msg InvalidConfig "$CONFIG_PATH")"
        return 1
    fi
    return 0
}

load_config_with_retry() {
    while true; do
        if load_config; then return 0; fi
        if [[ "$INTERACTIVE_MODE" != true ]]; then return 1; fi
        warn "$(msg ConfigReload)"
        read -r -p "$(msg InboxContinue): " _ || return 1
    done
}

resolve_path() {
    local input="$1" dir base
    if [[ ! -f "$input" ]]; then
        return 1
    fi
    dir="$(cd "$(dirname "$input")" >/dev/null 2>&1 && pwd -P)" || return 1
    base="$(basename "$input")"
    printf '%s/%s' "$dir" "$base"
}

collect_inbox_files() {
    INBOX_FILES=()
    shopt -s nullglob dotglob
    local path
    for path in "$INBOX"/*; do
        [[ -f "$path" ]] && INBOX_FILES+=("$path")
    done
    shopt -u nullglob dotglob
    if [[ ${#INBOX_FILES[@]} -gt 0 ]]; then
        local sorted line
        sorted=()
        while IFS= read -r line; do sorted+=("$line"); done < <(printf '%s\n' "${INBOX_FILES[@]}" | LC_ALL=C sort)
        INBOX_FILES=("${sorted[@]}")
    fi
}

get_inbox_package_paths() {
    mkdir -p "$INBOX" || return 1
    printf '\n%s\n  %s\n\n%s\n' "$(msg InboxIntro)" "$INBOX" "$(msg InboxOpen)"
    if ! open "$INBOX" >/dev/null 2>&1; then
        warn "$(msg InboxOpenFailed "open $INBOX")"
    fi

    while true; do
        read -r -p "$(msg InboxContinue): " _ || return 1
        collect_inbox_files
        local archives=() unsupported=() bad_names=() path name lower
        for path in "${INBOX_FILES[@]}"; do
            name="$(basename "$path")"
            lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
            if [[ "$lower" == *.zip ]]; then
                archives+=("$path")
                if [[ ! "$name" =~ ^(Win|Mac)_([A-Za-z0-9]+)_([0-9]+\.[0-9]+\.[0-9]+)(_Demo)?\.zip$ ]]; then
                    bad_names+=("$name")
                fi
            elif [[ "$lower" == *.rar || "$lower" == *.7z ]]; then
                unsupported+=("$name")
            fi
        done

        if [[ ${#unsupported[@]} -gt 0 ]]; then
            error "$(msg InboxUnsupported "${unsupported[*]}")"
            printf '  %s\n' "${unsupported[@]}"
        fi
        if [[ ${#bad_names[@]} -gt 0 ]]; then
            error "$(msg InvalidFileName "${bad_names[*]}")"
            printf '  %s\n' "${bad_names[@]}"
            printf '\n%s\n  Win_GameName_1.2.3.zip\n  Mac_GameName_1.2.3.zip\n  Win_GameName_1.2.3_Demo.zip\n  Mac_GameName_1.2.3_Demo.zip\n' "$(msg RequiredFormat)"
        fi
        if [[ ${#archives[@]} -eq 0 ]]; then
            warn "$(msg InboxEmpty "$INBOX")"
            continue
        fi
        if [[ ${#unsupported[@]} -gt 0 || ${#bad_names[@]} -gt 0 ]]; then
            warn "$(msg FixValidation)"
            continue
        fi
        info "$(msg InboxFound "${#archives[@]}")"
        SELECTED_PATHS=("${archives[@]}")
        return 0
    done
}

get_package_paths() {
    SELECTED_PATHS=()
    if [[ ${#PACKAGE_ARGS[@]} -eq 0 ]]; then
        get_inbox_package_paths
        return $?
    fi

    local item part
    for item in "${PACKAGE_ARGS[@]}"; do
        IFS=',' read -r -a parts <<< "$item"
        for part in "${parts[@]}"; do
            part="$(printf '%s' "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [[ -n "$part" ]] && SELECTED_PATHS+=("$part")
        done
    done
    if [[ ${#SELECTED_PATHS[@]} -eq 0 ]]; then
        error "$(msg PackagePathEmpty)"
        return 1
    fi
    return 0
}

json_has_game() {
    "$JQ_BIN" -e --arg game "$1" 'if (.games | type) == "object" then .games | has($game) else false end' "$CONFIG_PATH" >/dev/null 2>&1
}

json_has_release_property() {
    local game="$1" release="$2" property="$3"
    "$JQ_BIN" -e --arg game "$game" --arg release "$release" --arg property "$property" '
      if (.games[$game][$release] | type) == "object" then .games[$game][$release] | has($property) else false end
    ' "$CONFIG_PATH" >/dev/null 2>&1
}

json_has_depot() {
    local game="$1" release="$2" platform="$3"
    "$JQ_BIN" -e --arg game "$game" --arg release "$release" --arg platform "$platform" '
      if (.games[$game][$release].depots | type) == "object" then .games[$game][$release].depots | has($platform) else false end
    ' "$CONFIG_PATH" >/dev/null 2>&1
}

json_string() {
    local game="$1" release="$2" path="$3"
    "$JQ_BIN" -r --arg game "$game" --arg release "$release" --arg path "$path" '
      (getpath((["games", $game, $release] + ($path | split("."))))) as $v
      | if $v == null then "" elif ($v | type) == "string" then $v else ($v | tostring) end
    ' "$CONFIG_PATH" 2>/dev/null
}

resolve_target_entry() {
    local game="$1" release="$2" platform="$3" raw name lower extension
    if [[ "$platform" == "Win" ]]; then
        raw="$($JQ_BIN -r --arg game "$game" --arg release "$release" '
          .games[$game][$release]
          | [ .entryNames.Win, .entryNames.Windows, .entries.Win, .entries.Windows, .executables.Win, .executables.Windows ]
          | map(select(type == "string") | select((gsub("^[[:space:]]+|[[:space:]]+$"; "")) != ""))
          | .[0] // empty
        ' "$CONFIG_PATH" 2>/dev/null)"
        extension='.exe'
    else
        raw="$($JQ_BIN -r --arg game "$game" --arg release "$release" '
          .games[$game][$release]
          | [ .entryNames.Mac, .entryNames.MacOS, .entries.Mac, .entries.MacOS, .apps.Mac, .apps.MacOS ]
          | map(select(type == "string") | select((gsub("^[[:space:]]+|[[:space:]]+$"; "")) != ""))
          | .[0] // empty
        ' "$CONFIG_PATH" 2>/dev/null)"
        extension='.app'
    fi
    raw="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ -z "$raw" ]]; then
        error "$(msg EntryNamesMissing "$game" "$release" "$platform")"
        return 1
    fi
    name="$(basename "$raw")"
    lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower" != *"$extension" ]]; then name="$name$extension"; fi
    if [[ -z "$name" || "$name" == '.' || "$name" == '..' || "$name" == */* ]]; then
        fail "Config entry name is invalid: $raw"
        return 1
    fi
    TARGET_ENTRY_NAME="$name"
    TARGET_ENTRY_STEM="${name%.*}"
    return 0
}

resolve_game_config() {
    local game="$1" is_demo="$2" platform="$3" release release_label app depot
    if ! "$JQ_BIN" -e '.games and ((.games | type) == "object")' "$CONFIG_PATH" >/dev/null 2>&1; then
        error "$(msg MissingGames "$CONFIG_PATH")"
        return 1
    fi
    if ! json_has_game "$game"; then
        error "$(msg GameMissing "$game" "$CONFIG_PATH")"
        return 1
    fi
    if [[ "$is_demo" == true ]]; then release='demo'; release_label="$(msg DemoRelease)"; else release='full'; release_label="$(msg FullRelease)"; fi
    if ! "$JQ_BIN" -e --arg game "$game" --arg release "$release" '.games[$game] | has($release)' "$CONFIG_PATH" >/dev/null 2>&1; then
        error "$(msg ReleaseMissing "$game" "$release_label" "$release")"
        return 1
    fi
    if ! json_has_release_property "$game" "$release" appId; then
        error "$(msg AppIdMissing "$game" "$release")"
        return 1
    fi
    if ! json_has_release_property "$game" "$release" depots; then
        error "$(msg DepotsMissing "$game" "$release")"
        return 1
    fi
    if ! json_has_depot "$game" "$release" "$platform"; then
        error "$(msg DepotMissing "$game" "$platform" "$release")"
        return 1
    fi
    app="$(json_string "$game" "$release" appId)"
    depot="$($JQ_BIN -r --arg game "$game" --arg release "$release" --arg platform "$platform" '
      .games[$game][$release].depots[$platform]
      | if . == null then "" elif (type == "string") then . else tostring end
    ' "$CONFIG_PATH" 2>/dev/null)"
    if [[ -z "$app" || "$app" == TODO* || -z "$depot" || "$depot" == TODO* ]]; then
        if [[ "$ALLOW_PLACEHOLDER_CONFIG" != true ]]; then
            error "$(msg PlaceholderConfig "$game" "$release" "$platform")"
            return 1
        fi
    fi
    if ! resolve_target_entry "$game" "$release" "$platform"; then return 1; fi
    RESOLVED_RELEASE="$release"
    RESOLVED_APP_ID="$app"
    RESOLVED_DEPOT_ID="$depot"
    RESOLVED_TARGET_ENTRY="$TARGET_ENTRY_NAME"
    RESOLVED_TARGET_STEM="$TARGET_ENTRY_STEM"
    return 0
}

parse_package() {
    local input="$1" source name lower platform game version demo
    if [[ -z "$input" ]]; then
        error "$(msg PackagePathEmpty)"
        return 1
    fi
    if ! source="$(resolve_path "$input")"; then
        error "Package does not exist: $input"
        return 1
    fi
    name="$(basename "$source")"
    lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower" == *.rar || "$lower" == *.7z ]]; then
        error "$(msg UnsupportedArchive "$name")"
        return 1
    fi
    if [[ ! "$name" =~ ^(Win|Mac)_([A-Za-z0-9]+)_([0-9]+\.[0-9]+\.[0-9]+)(_Demo)?\.zip$ ]]; then
        error "$(msg InvalidFileName "$name")"
        return 1
    fi
    platform="${BASH_REMATCH[1]}"
    game="${BASH_REMATCH[2]}"
    version="${BASH_REMATCH[3]}"
    [[ -n "${BASH_REMATCH[4]}" ]] && demo=true || demo=false
    if ! resolve_game_config "$game" "$demo" "$platform"; then return 1; fi
    PARSED_SOURCE="$source"
    PARSED_FILE="$name"
    PARSED_PLATFORM="$platform"
    PARSED_GAME="$game"
    PARSED_VERSION="$version"
    PARSED_RELEASE="$RESOLVED_RELEASE"
    PARSED_APP_ID="$RESOLVED_APP_ID"
    PARSED_DEPOT_ID="$RESOLVED_DEPOT_ID"
    PARSED_TARGET_ENTRY="$RESOLVED_TARGET_ENTRY"
    PARSED_TARGET_STEM="$RESOLVED_TARGET_STEM"
    return 0
}

resolve_packages_with_retry() {
    while true; do
        PKG_SOURCE=(); PKG_FILE=(); PKG_PLATFORM=(); PKG_GAME=(); PKG_VERSION=(); PKG_RELEASE=(); PKG_APP_ID=(); PKG_DEPOT_ID=(); PKG_TARGET_ENTRY=(); PKG_TARGET_STEM=()
        local errors_path=() errors_message=() path index
        for path in "${SELECTED_PATHS[@]}"; do
            if parse_package "$path"; then
                index=${#PKG_SOURCE[@]}
                PKG_SOURCE[index]="$PARSED_SOURCE"
                PKG_FILE[index]="$PARSED_FILE"
                PKG_PLATFORM[index]="$PARSED_PLATFORM"
                PKG_GAME[index]="$PARSED_GAME"
                PKG_VERSION[index]="$PARSED_VERSION"
                PKG_RELEASE[index]="$PARSED_RELEASE"
                PKG_APP_ID[index]="$PARSED_APP_ID"
                PKG_DEPOT_ID[index]="$PARSED_DEPOT_ID"
                PKG_TARGET_ENTRY[index]="$PARSED_TARGET_ENTRY"
                PKG_TARGET_STEM[index]="$PARSED_TARGET_STEM"
            else
                errors_path+=("$path")
                errors_message+=("$LAST_ERROR")
            fi
        done
        if [[ ${#errors_path[@]} -eq 0 ]]; then
            return 0
        fi
        if [[ "$INTERACTIVE_MODE" != true ]]; then
            local n
            for ((n=0; n<${#errors_path[@]}; n++)); do error "${errors_path[n]}: ${errors_message[n]}"; done
            return 1
        fi
        error "$(msg ValidationProblems)"
        local n
        for ((n=0; n<${#errors_path[@]}; n++)); do
            printf '  %s\n    %s\n' "${errors_path[n]}" "${errors_message[n]}" >&2
        done
        warn "$(msg FixValidation)"
        read -r -p "$(msg InboxContinue): " _ || return 1
        load_config_with_retry || return 1
        get_inbox_package_paths || return 1
    done
}

build_tasks() {
    TASK_KEYS=(); TASK_INDEXES=()
    local i key j duplicate
    for ((i=0; i<${#PKG_SOURCE[@]}; i++)); do
        key="${PKG_APP_ID[i]}|${PKG_GAME[i]}|${PKG_RELEASE[i]}|${PKG_VERSION[i]}|${PKG_PLATFORM[i]}"
        duplicate=false
        for j in "${!TASK_KEYS[@]}"; do
            if [[ "${TASK_KEYS[j]}" == "$key" ]]; then duplicate=true; break; fi
        done
        if [[ "$duplicate" == true ]]; then
            error "$(msg DuplicatePlatform "${PKG_PLATFORM[i]}" "$key")"
            return 1
        fi
        TASK_KEYS+=("$key")
        TASK_INDEXES+=("$i")
    done
    return 0
}

print_packages() {
    printf '\n'
    printf '%-10s %-18s %-10s %-10s %-10s %-10s %s\n' Platform Game Version Release AppID DepotID File
    local rows line platform game version release app depot file
    rows=()
    local i
    for ((i=0; i<${#PKG_SOURCE[@]}; i++)); do
        rows+=("${PKG_GAME[i]}"$'\t'"${PKG_RELEASE[i]}"$'\t'"${PKG_VERSION[i]}"$'\t'"${PKG_PLATFORM[i]}"$'\t'"${PKG_APP_ID[i]}"$'\t'"${PKG_DEPOT_ID[i]}"$'\t'"${PKG_FILE[i]}")
    done
    while IFS=$'\t' read -r game release version platform app depot file; do
        [[ -n "$game" ]] || continue
        printf '%-10s %-18s %-10s %-10s %-10s %-10s %s\n' "$platform" "$game" "$version" "$release" "$app" "$depot" "$file"
    done < <(printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t $'\t' -k1,1 -k2,2 -k3,3 -k4,4)
}

task_label() {
    local i="$1"
    printf '%s %s %s [%s]' "${PKG_GAME[i]}" "${PKG_VERSION[i]}" "${PKG_RELEASE[i]}" "${PKG_PLATFORM[i]}"
}

show_plan() {
    printf '\n%s\n' "$(msg TaskPlan)"
    local i pkg_index
    for i in "${!TASK_INDEXES[@]}"; do
        pkg_index="${TASK_INDEXES[i]}"
        msg TaskLine "${PKG_APP_ID[pkg_index]}" "${PKG_GAME[pkg_index]}" "${PKG_VERSION[pkg_index]}" "${PKG_RELEASE[pkg_index]}" "${PKG_PLATFORM[pkg_index]}:Depot ${PKG_DEPOT_ID[pkg_index]}"
        printf '\n'
    done
}

ensure_clean_directory() {
    local path="$1" target item items=()
    if [[ ! -e "$path" ]]; then mkdir -p "$path" || return 1; return 0; fi
    target="$(cd "$path" >/dev/null 2>&1 && pwd -P)" || return 1
    case "$target/" in
        "$WORKSPACE"/*/) ;;
        *) error "$(msg RefuseClean "$path")"; return 1 ;;
    esac
    shopt -s nullglob dotglob
    for item in "$path"/*; do items+=("$item"); done
    shopt -u nullglob dotglob
    if [[ ${#items[@]} -gt 0 ]]; then rm -rf "${items[@]}" || return 1; fi
    return 0
}

remove_mac_junk() {
    local path="$1"
    find "$path" -type d -name '__MACOSX' -prune -exec rm -rf {} \; 2>/dev/null || true
    find "$path" -type f -name '.DS_Store' -exec rm -f {} \; 2>/dev/null || true
}

effective_content_root() {
    local path="$1" item base items=()
    shopt -s nullglob dotglob
    for item in "$path"/*; do
        [[ -e "$item" ]] || continue
        base="$(basename "$item")"
        [[ "$base" == '__MACOSX' || "$base" == '.DS_Store' ]] && continue
        items+=("$item")
    done
    shopt -u nullglob dotglob
    if [[ ${#items[@]} -eq 1 && -d "${items[0]}" ]]; then
        EFFECTIVE_ROOT="${items[0]}"
    else
        EFFECTIVE_ROOT="$path"
    fi
}

lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

rename_unity_data_directory() {
    local root="$1" old_stem="$2" new_stem="$3" suffix old_name new_name
    [[ "$(lowercase "$old_stem")" == "$(lowercase "$new_stem")" ]] && return 0
    for suffix in _Data _Date; do
        old_name="${old_stem}${suffix}"; new_name="${new_stem}${suffix}"
        if [[ -d "$root/$old_name" ]]; then
            if [[ -e "$root/$new_name" ]]; then
                error "$(msg EntryTargetExists "$old_name" "$new_name")"; return 1
            fi
            if ! mv "$root/$old_name" "$root/$new_name"; then
                fail "Could not rename $root/$old_name"
                return 1
            fi
            warn "$(msg DataRenamed Win "$old_name" "$new_name")"
        fi
    done
    return 0
}

mac_plist_executable() {
    local app_path plist
    app_path="$1"
    plist="$app_path/Contents/Info.plist"
    [[ -f "$plist" ]] || return 0
    plutil -extract CFBundleExecutable raw -o - "$plist" 2>/dev/null || true
}

set_mac_plist_executable() {
    local app_path executable plist current
    app_path="$1"
    executable="$2"
    plist="$app_path/Contents/Info.plist"
    [[ -f "$plist" ]] || return 0
    current="$(mac_plist_executable "$app_path")"
    if [[ -n "$current" && "$current" != "$executable" ]]; then
        if ! plutil -replace CFBundleExecutable -string "$executable" "$plist" >/dev/null 2>&1; then
            fail "Could not update $plist"
            return 1
        fi
        warn "$(msg PlistUpdated "$executable")"
    fi
    return 0
}

set_mac_plist_field_if_present() {
    local app_path key value plist current
    app_path="$1"
    key="$2"
    value="$3"
    plist="$app_path/Contents/Info.plist"
    [[ -f "$plist" ]] || return 0
    current="$(plutil -extract "$key" raw -o - "$plist" 2>/dev/null || true)"
    [[ -n "$current" && "$current" != "$value" ]] || return 0
    if ! plutil -replace "$key" -string "$value" "$plist" >/dev/null 2>&1; then
        fail "Could not update $plist field $key"
        return 1
    fi
    warn "$(msg PlistFieldUpdated "$key" "$value")"
    return 0
}

set_mac_bundle_metadata() {
    local app_path bundle_name="$2"
    app_path="$1"
    set_mac_plist_field_if_present "$app_path" CFBundleName "$bundle_name" || return 1
    set_mac_plist_field_if_present "$app_path" CFBundleDisplayName "$bundle_name" || return 1
    return 0
}

rename_mac_helper_bundles() {
    local app_path="$1" new_stem="$2" frameworks_dir bundle base base_without_ext identity helper_prefix helper_suffix target_base target_bundle
    [[ -d "$app_path/Contents/Frameworks" ]] || return 0
    frameworks_dir="$app_path/Contents/Frameworks"
    shopt -s nullglob dotglob
    for bundle in "$frameworks_dir"/*.app; do
        [[ -d "$bundle" ]] || continue
        base="$(basename "$bundle")"
        base_without_ext="${base%.app}"
        identity="$(mac_plist_executable "$bundle")"
        [[ -n "$identity" ]] || identity="$base_without_ext"

        # Electron helper bundles use: <ProductName> Helper[ (GPU|Plugin|Renderer)].app.
        # Accept both the old product prefix and Electron's default prefix so a
        # package can be repaired even when only part of the rebranding happened.
        if [[ "$identity" != *' Helper'* && "$base_without_ext" != *' Helper'* ]]; then
            continue
        fi
        if [[ "$identity" == *' Helper'* ]]; then
            helper_prefix="${identity%% Helper*}"
            helper_suffix="${identity#"$helper_prefix"}"
        else
            helper_prefix="${base_without_ext%% Helper*}"
            helper_suffix="${base_without_ext#"$helper_prefix"}"
        fi
        [[ -n "$helper_prefix" && "$helper_suffix" == ' Helper'* ]] || continue
        target_base="${new_stem}${helper_suffix}"
        target_bundle="$frameworks_dir/$target_base.app"

        if [[ "$base" != "$target_base.app" ]]; then
            if [[ -e "$target_bundle" ]]; then
                shopt -u nullglob dotglob
                error "$(msg EntryTargetExists "$base" "$(basename "$target_bundle")")"
                return 1
            fi
            if ! mv "$bundle" "$target_bundle"; then
                shopt -u nullglob dotglob
                fail "Could not rename $bundle to $target_bundle"
                return 1
            fi
            warn "$(msg HelperBundleRenamed "$base" "$(basename "$target_bundle")")"
        fi
        ensure_mac_bundle_executable "$target_bundle" "$target_base" || { shopt -u nullglob dotglob; return 1; }
        set_mac_bundle_metadata "$target_bundle" "$target_base" || { shopt -u nullglob dotglob; return 1; }
    done
    shopt -u nullglob dotglob
    return 0
}

ensure_mac_bundle_executable() {
    local app_path target_name macos_dir target_path declared declared_path candidate item base names=()
    app_path="$1"
    target_name="$2"
    macos_dir="$app_path/Contents/MacOS"
    [[ -d "$macos_dir" ]] || { error "$(msg NoMacExec "$macos_dir")"; return 1; }
    target_path="$macos_dir/$target_name"
    if [[ ! -f "$target_path" ]]; then
        declared="$(mac_plist_executable "$app_path")"
        if [[ -n "$declared" && -f "$macos_dir/$declared" ]]; then
            candidate="$macos_dir/$declared"
        else
            shopt -s nullglob dotglob
            for item in "$macos_dir"/*; do
                [[ -f "$item" ]] || continue
                base="$(basename "$item")"
                [[ "$base" == '.DS_Store' ]] && continue
                names+=("$base")
            done
            shopt -u nullglob dotglob
            if [[ ${#names[@]} -eq 0 ]]; then error "$(msg NoMacExec "$macos_dir")"; return 1; fi
            if [[ ${#names[@]} -gt 1 ]]; then error "$(msg MultiMacExec "$macos_dir" "${names[*]}")"; return 1; fi
            candidate="$macos_dir/${names[0]}"
        fi
        if ! mv "$candidate" "$target_path"; then
            fail "Could not rename $candidate to $target_path"
            return 1
        fi
        warn "$(msg MacExecRenamed "$(basename "$candidate")" "$target_name")"
    fi
    set_mac_plist_executable "$app_path" "$target_name"
}

ensure_entry_name() {
    local content_dir="$1" package_index="$2" root platform target_name target_stem item base lower candidates=() entry before old_stem parent target_path ignored=()
    effective_content_root "$content_dir"
    root="$EFFECTIVE_ROOT"
    platform="${PKG_PLATFORM[package_index]}"
    target_name="${PKG_TARGET_ENTRY[package_index]}"
    target_stem="${PKG_TARGET_STEM[package_index]}"
    info "$(msg TargetEntry "$target_name")"

    if [[ "$platform" == Win ]]; then
        shopt -s nullglob dotglob
        for item in "$root"/*; do
            [[ -f "$item" ]] || continue
            base="$(basename "$item")"; lower="$(lowercase "$base")"
            if [[ "$lower" == crashhandler*.exe ]]; then ignored+=("$base"); continue; fi
            [[ "$lower" == *.exe ]] && candidates+=("$item")
        done
        shopt -u nullglob dotglob
        for base in "${ignored[@]}"; do info "$(msg IgnoreCrash "$base")"; done
    else
        shopt -s nullglob dotglob
        if [[ -d "$root" && "$(lowercase "$(basename "$root")")" == *.app ]]; then
            candidates=("$root")
        else
            for item in "$root"/*; do
                [[ -d "$item" ]] || continue
                lower="$(lowercase "$(basename "$item")")"
                [[ "$lower" == *.app ]] && candidates+=("$item")
            done
        fi
        shopt -u nullglob dotglob
    fi
    if [[ ${#candidates[@]} -eq 0 ]]; then error "$(msg NoEntry "$target_name" "$root")"; return 1; fi
    if [[ ${#candidates[@]} -gt 1 ]]; then
        local candidate_names=()
        for item in "${candidates[@]}"; do candidate_names+=("$(basename "$item")"); done
        error "$(msg MultiEntry "$root" "${candidate_names[*]}")"
        return 1
    fi
    entry="${candidates[0]}"; before="$(basename "$entry")"; old_stem="${before%.*}"; parent="$(dirname "$entry")"; target_path="$parent/$target_name"
    if [[ "$before" == "$target_name" ]]; then
        info "$(msg EntryOk "$platform" "$target_name")"
        if [[ "$platform" == Win ]]; then
            rename_unity_data_directory "$parent" "$old_stem" "$target_stem" || return 1
        else
            ensure_mac_bundle_executable "$entry" "$target_stem" || return 1
            set_mac_bundle_metadata "$entry" "$target_stem" || return 1
            rename_mac_helper_bundles "$entry" "$target_stem" || return 1
        fi
        return 0
    fi
    if [[ -e "$target_path" ]]; then error "$(msg EntryTargetExists "$before" "$target_name")"; return 1; fi
    if ! mv "$entry" "$target_path"; then fail "Could not rename $entry to $target_path"; return 1; fi
    warn "$(msg EntryRenamed "$platform" "$before" "$target_name")"
    if [[ "$platform" == Win ]]; then
        rename_unity_data_directory "$parent" "$old_stem" "$target_stem" || return 1
    else
        ensure_mac_bundle_executable "$target_path" "$target_stem" || return 1
        set_mac_bundle_metadata "$target_path" "$target_stem" || return 1
        rename_mac_helper_bundles "$target_path" "$target_stem" || return 1
    fi
    return 0
}

expand_package() {
    local package_index="$1" archive_dir="$WORKSPACE/archives" archive_copy platform_dir content_dir
    archive_copy="$archive_dir/${PKG_FILE[package_index]}"
    platform_dir='win_build'; [[ "${PKG_PLATFORM[package_index]}" == Mac ]] && platform_dir='mac_build'
    content_dir="$WORKSPACE/content/${PKG_APP_ID[package_index]}/$platform_dir"
    mkdir -p "$archive_dir" || { fail "Could not create $archive_dir"; return 1; }
    if ! cp -f "${PKG_SOURCE[package_index]}" "$archive_copy"; then fail "Could not copy ${PKG_FILE[package_index]}"; return 1; fi
    if ! ensure_clean_directory "$content_dir"; then return 1; fi
    info "$(msg Extracting "${PKG_FILE[package_index]}" "$content_dir")"
    if ! unzip -oq "$archive_copy" -d "$content_dir"; then fail "Could not extract ${PKG_FILE[package_index]}"; return 1; fi
    remove_mac_junk "$content_dir"
    ensure_entry_name "$content_dir" "$package_index"
}

vdf_escape() {
    local value="$1"
    value="${value//\\/\/}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

write_depot_vdf() {
    local path="$1" depot_id="$2" content_root="$3" root_value
    root_value="$(vdf_escape "$content_root")"
    printf '"DepotBuildConfig"\n{\n    "DepotID" "%s"\n    "ContentRoot" "%s"\n    "FileMapping"\n    {\n        "LocalPath" "*"\n        "DepotPath" "."\n        "recursive" "1"\n    }\n    "FileExclusion" "*.DS_Store"\n    "FileExclusion" "__MACOSX"\n}\n' "$depot_id" "$root_value" > "$path"
}

write_app_vdf() {
    local path="$1" app_id="$2" description="$3" output_dir="$4" content_root="$5" set_live="$6" depot_id="$7" depot_script="$8" output_value root_value
    output_value="$(vdf_escape "$output_dir")"; root_value="$(vdf_escape "$content_root")"
    {
        printf '"appbuild"\n{\n'
        printf '    "appid" "%s"\n    "desc" "%s"\n    "buildoutput" "%s"\n    "contentroot" "%s"\n' "$app_id" "$description" "$output_value" "$root_value"
        [[ -n "$set_live" ]] && printf '    "setlive" "%s"\n' "$set_live"
        printf '    "depots"\n    {\n        "%s" "%s"\n    }\n}\n' "$depot_id" "$depot_script"
    } > "$path"
}

new_vdf_files() {
    local package_index script_dir output_dir content_root platform_dir depot_path app_path set_live desc
    package_index="$1"
    script_dir="$WORKSPACE/scripts/${PKG_APP_ID[package_index]}"
    output_dir="$WORKSPACE/output/${PKG_APP_ID[package_index]}"
    content_root="$WORKSPACE/content/${PKG_APP_ID[package_index]}"
    mkdir -p "$script_dir" "$output_dir" || { fail 'Could not create VDF workspace directories'; return 1; }
    platform_dir='win_build/'; [[ "${PKG_PLATFORM[package_index]}" == Mac ]] && platform_dir='mac_build/'
    depot_path="$script_dir/depot_build_${PKG_DEPOT_ID[package_index]}.vdf"
    if ! write_depot_vdf "$depot_path" "${PKG_DEPOT_ID[package_index]}" "$platform_dir"; then fail "Could not write $depot_path"; return 1; fi
    set_live="$($JQ_BIN -r '.setLive // ""' "$CONFIG_PATH" 2>/dev/null)"
    desc="${PKG_GAME[package_index]}_${PKG_VERSION[package_index]}_${PKG_RELEASE[package_index]}_${PKG_PLATFORM[package_index]}_Auto"
    app_path="$script_dir/app_build_${PKG_APP_ID[package_index]}.vdf"
    if ! write_app_vdf "$app_path" "${PKG_APP_ID[package_index]}" "$desc" "$output_dir" "$content_root" "$set_live" "${PKG_DEPOT_ID[package_index]}" "$(basename "$depot_path")"; then fail "Could not write $app_path"; return 1; fi
    VDF_APP="$app_path"; VDF_OUTPUT="$output_dir"; VDF_DESCRIPTION="$desc"
    return 0
}

invoke_steam_upload() {
    local package_index="$1" login_log retry_answer login_error attempt=1 exit_code
    if [[ -z "$STEAM_CMD_PATH" ]]; then
        resolve_steam_cmd_path || return 1
    fi
    if [[ ! -f "$STEAM_CMD_PATH" || ! -x "$STEAM_CMD_PATH" ]]; then
        error "$(msg SteamCmdMissing "$STEAM_CMD_PATH")"
        return 1
    fi
    [[ -n "$STEAM_USER" ]] || { error "$(msg SteamUserEmpty)"; return 1; }
    login_log="$(mktemp "${TMPDIR:-/tmp}/steampackflow-login.XXXXXX")" || {
        fail 'Could not create the temporary SteamCMD login log.'
        return 1
    }

    while true; do
        : > "$login_log"
        info "$(msg SteamCmdAttempt "$attempt")"
        info "$(msg Uploading "${PKG_APP_ID[package_index]}" "$STEAM_CMD_PATH")"
        # Keep SteamCMD attached to the terminal so its password and Steam
        # Guard prompts remain interactive, while retaining output for error
        # classification. The password itself is never written by this script.
        "$STEAM_CMD_PATH" +login "$STEAM_USER" +run_app_build "$VDF_APP" +quit 2>&1 | tee "$login_log"
        exit_code=${PIPESTATUS[0]}
        if [[ $exit_code -eq 0 ]]; then
            rm -f "$login_log"
            return 0
        fi

        login_error=''
        if grep -Eiq 'invalid[[:space:]]+password|incorrect[[:space:]]+password|password[[:space:]]+is[[:space:]]+invalid' "$login_log"; then
            login_error='password'
            warn "$(msg SteamPasswordRetry)"
        elif grep -Eiq 'invalid[[:space:]]+(login[[:space:]]+)?(auth|guard|two-factor)|invalid.*(auth|guard)[[:space:]]+code|incorrect.*(auth|guard).*code|two-factor.*invalid' "$login_log"; then
            login_error='guard'
            warn "$(msg SteamGuardRetry)"
        fi

        if [[ -n "$login_error" ]]; then
            read -r -p "$(msg SteamLoginRetryPrompt): " retry_answer || {
                rm -f "$login_log"
                return 1
            }
            retry_answer="$(lowercase "$(printf '%s' "$retry_answer" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")"
            if [[ "$retry_answer" == q || "$retry_answer" == quit || "$retry_answer" == cancel ]]; then
                rm -f "$login_log"
                error "$(msg SteamCmdFailed "${PKG_APP_ID[package_index]}" "$exit_code" "$VDF_OUTPUT")"
                return 1
            fi
            attempt=$((attempt + 1))
            continue
        fi

        rm -f "$login_log"
        error "$(msg SteamCmdFailed "${PKG_APP_ID[package_index]}" "$exit_code" "$VDF_OUTPUT")"
        return 1
    done
}

resolve_steam_cmd_path() {
    local configured_path
    configured_path="$($JQ_BIN -r '.steamCmdPath // ""' "$CONFIG_PATH" 2>/dev/null)"
    [[ -n "$configured_path" ]] || configured_path='builder/steamcmd.sh'
    configured_path="${configured_path//\\/\/}"
    [[ "$configured_path" = /* ]] || configured_path="$ROOT/$configured_path"
    STEAM_CMD_PATH="$configured_path"
    return 0
}

ensure_steam_cmd() {
    local install_dir install_command
    resolve_steam_cmd_path || return 1

    if [[ -f "$STEAM_CMD_PATH" && ! -x "$STEAM_CMD_PATH" ]]; then
        chmod +x "$STEAM_CMD_PATH" 2>/dev/null || true
    fi
    if [[ -f "$STEAM_CMD_PATH" && -x "$STEAM_CMD_PATH" ]]; then
        info "$(msg SteamCmdReady "$STEAM_CMD_PATH")"
        return 0
    fi

    if [[ "$(basename "$STEAM_CMD_PATH")" != 'steamcmd.sh' ]]; then
        error "$(msg SteamCmdMissing "$STEAM_CMD_PATH")"
        error "$(msg SteamCmdInstallFailed "$ROOT/InstallSteamCMD.sh --install-dir $(dirname "$STEAM_CMD_PATH")")"
        return 1
    fi
    install_dir="$(dirname "$STEAM_CMD_PATH")"
    install_command="$ROOT/InstallSteamCMD.sh --install-dir $install_dir"
    if [[ ! -x "$ROOT/InstallSteamCMD.sh" ]]; then
        error "$(msg SteamCmdInstallFailed "$install_command")"
        return 1
    fi
    info "$(msg SteamCmdDownloading "$install_dir")"
    if ! "$ROOT/InstallSteamCMD.sh" --install-dir "$install_dir"; then
        error "$(msg SteamCmdInstallFailed "$install_command")"
        return 1
    fi
    if [[ ! -f "$STEAM_CMD_PATH" || ! -x "$STEAM_CMD_PATH" ]]; then
        error "$(msg SteamCmdMissing "$STEAM_CMD_PATH")"
        return 1
    fi
    info "$(msg SteamCmdReady "$STEAM_CMD_PATH")"
    return 0
}

move_succeeded_inbox_package_to_done() {
    local package_index source source_dir done_dir destination stem extension timestamp index
    package_index="$1"
    source="${PKG_SOURCE[package_index]}"
    [[ -n "$source" ]] || return 0
    source_dir="$(dirname "$source")"
    [[ "$source_dir" == "$INBOX" ]] || return 0
    done_dir="$INBOX/done"
    mkdir -p "$done_dir" || { warn "$(msg MoveDoneFailure "${PKG_FILE[package_index]}" "could not create $done_dir")"; return 0; }
    destination="$done_dir/${PKG_FILE[package_index]}"
    if [[ -e "$destination" ]]; then
        stem="${PKG_FILE[package_index]%.zip}"; extension='.zip'; timestamp="$(date '+%Y%m%d_%H%M%S')"; index=1
        destination="$done_dir/${stem}_${timestamp}_${index}${extension}"
        while [[ -e "$destination" ]]; do index=$((index + 1)); destination="$done_dir/${stem}_${timestamp}_${index}${extension}"; done
    fi
    if ! mv "$source" "$destination"; then
        warn "$(msg MoveDoneFailure "${PKG_FILE[package_index]}" 'move failed')"
        return 0
    fi
    MOVED_DONE_NAMES+=("$(basename "$destination")")
    info "$(msg MovedDone "$(basename "$destination")")"
}

record_failure() {
    FAILED_TASKS+=("$1"); FAILED_REASONS+=("$2"); FAILED_DETAILS+=("$3")
}

prompt_open_steamworks() {
    local app_id answer seen item
    if [[ ${#SUCCESS_APP_IDS[@]:-0} -eq 0 ]]; then
        return 0
    fi
    for app_id in "${SUCCESS_APP_IDS[@]}"; do
        seen=false
        for item in "${SEEN_APP_IDS[@]-}"; do [[ "$item" == "$app_id" ]] && seen=true; done
        [[ "$seen" == true ]] && continue
        SEEN_APP_IDS+=("$app_id")
        printf 'Steamworks: https://partner.steamgames.com/apps/builds/%s\n' "$app_id"
        read -r -p "$(msg OpenSteamworks) " answer || return 0
        answer="$(lowercase "$answer")"
        if [[ "$answer" == y || "$answer" == yes ]]; then open "https://partner.steamgames.com/apps/builds/$app_id" >/dev/null 2>&1 || true; fi
    done
}

get_steam_user() {
    if [[ -n "$STEAM_USER" ]]; then STEAM_USER="$(printf '%s' "$STEAM_USER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"; else read -r -p "$(msg SteamUserPrompt): " STEAM_USER || return 1; fi
    [[ -n "$STEAM_USER" ]] || { error "$(msg SteamUserRequired)"; return 1; }
    return 0
}

main() {
    parse_args "$@" || return 1
    printf '%s\n' "$(msg Title)"
    if [[ "$PLAN_ONLY" == true ]]; then warn "$(msg PlanOnlyMode)"; elif [[ "$DRY_RUN" == true ]]; then warn "$(msg DryRunMode)"; fi
    require_dependencies || return 1
    load_config_with_retry || return 1
    get_package_paths || return 1
    resolve_packages_with_retry || return 1
    print_packages
    build_tasks || return 1
    SHOW_FORMAT_HINT=false
    show_plan
    if [[ "$PLAN_ONLY" == true ]]; then info "$(msg PlanComplete)"; return 0; fi
    if [[ "$DRY_RUN" != true ]]; then
        ensure_steam_cmd || return 1
        get_steam_user || return 1
        warn "$(msg PasswordHint)"
    fi

    FAILED_TASKS=(); FAILED_REASONS=(); FAILED_DETAILS=(); SUCCESS_APP_IDS=(); MOVED_DONE_NAMES=(); SEEN_APP_IDS=()
    local task_number package_index label platforms detail
    for task_number in "${!TASK_INDEXES[@]}"; do
        package_index="${TASK_INDEXES[task_number]}"
        label="$(task_label "$package_index")"
        platforms="${PKG_PLATFORM[package_index]}"
        info "$(msg Preparing "${PKG_APP_ID[package_index]}" "${PKG_GAME[package_index]}" "${PKG_VERSION[package_index]}" "${PKG_RELEASE[package_index]}") [$platforms]"
        LAST_ERROR=''
        if ! expand_package "$package_index"; then
            detail="$LAST_ERROR"
            record_failure "$label" "$(msg PackagePreparationFailed "${PKG_FILE[package_index]}")" "$detail"
            continue
        fi
        if ! new_vdf_files "$package_index"; then
            detail="$LAST_ERROR"
            record_failure "$label" "$(msg PackagePreparationFailed "${PKG_FILE[package_index]}")" "$detail"
            continue
        fi
        info "$(msg GeneratedAppVdf "$VDF_APP")"
        info "$(msg BuildDescription "$VDF_DESCRIPTION")"
        if [[ "$DRY_RUN" == true ]]; then
            warn "$(msg DryRunSkipped "${PKG_APP_ID[package_index]}")"
            SUCCESS_APP_IDS+=("${PKG_APP_ID[package_index]}")
            continue
        fi
        if invoke_steam_upload "$package_index"; then
            info "$(msg UploadFinished "${PKG_APP_ID[package_index]}" "$VDF_OUTPUT")"
            move_succeeded_inbox_package_to_done "$package_index"
            SUCCESS_APP_IDS+=("${PKG_APP_ID[package_index]}")
        else
            record_failure "$label" "$(msg UploadFailed)" "${LAST_ERROR:-SteamCMD returned a failure}"
        fi
    done

    prompt_open_steamworks
    if [[ ${#FAILED_TASKS[@]} -gt 0 ]]; then
        printf '\n%s\n' "$(msg FailedTasks)"
        local n
        for ((n=0; n<${#FAILED_TASKS[@]}; n++)); do
            printf '%s\n  %s\n' "$(msg FailedLine "${FAILED_TASKS[n]}" "${FAILED_REASONS[n]}")" "${FAILED_DETAILS[n]}" >&2
        done
    fi
    printf '\n%s\n' "$(msg Done)"
    [[ ${#FAILED_TASKS[@]} -eq 0 ]]
}

main "$@"
exit_code=$?
if [[ $exit_code -ne 0 && "$SHOW_FORMAT_HINT" == true ]]; then
    printf '\n%s\n' "$(msg RequiredFormat)" >&2
    printf '  Win_GameName_1.2.3.zip\n  Mac_GameName_1.2.3.zip\n  Win_GameName_1.2.3_Demo.zip\n  Mac_GameName_1.2.3_Demo.zip\n' >&2
fi
exit "$exit_code"
