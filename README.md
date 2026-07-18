# SteamPackFlow

SteamPackFlow is a SteamCMD upload workflow for validating package names, normalizing entry files, generating VDF files, and uploading builds on Windows and macOS.<br/>**SteamPackFlow 是一个支持 Windows 和 macOS 的 SteamCMD 上传工作流，用于校验压缩包命名、规范化入口文件、生成 VDF 文件并上传构建。**

## Overview

The repository provides equivalent workflows under `Win/` and `Mac/`. Each workflow keeps its own inbox, builder, config, and generated workspace so the same release configuration can be used on either operating system.<br/>**仓库在 `Win/` 和 `Mac/` 下提供功能对应的上传流程。每个流程都有独立的收件箱、SteamCMD、配置和生成 workspace，同时可以使用相同的发行配置。**

It scans packages from the selected workflow's `inbox`, validates file names, extracts content into that workflow's `workspace`, fixes entry names, queues each platform package as its own upload task, and submits builds through SteamCMD.<br/>**它会从所选流程的 `inbox` 扫描压缩包，校验文件命名，解压到对应的 `workspace`，修正入口名称，并把每个平台压缩包分别排成独立上传任务，再通过 SteamCMD 提交构建。**

## Setup

- Put the Windows SteamCMD executable at `Win/builder/steamcmd.exe`, or the macOS SteamCMD launcher at `Mac/builder/steamcmd.sh` and make it executable.<br/>**把 Windows 版 SteamCMD 放到 `Win/builder/steamcmd.exe`，或者把 macOS 版 SteamCMD 启动脚本放到 `Mac/builder/steamcmd.sh` 并赋予执行权限。**
- On macOS, install `jq` first (`brew install jq`); `unzip`, `plutil`, and `open` are provided by macOS.<br/>**在 macOS 上请先安装 `jq`（`brew install jq`）；`unzip`、`plutil` 和 `open` 由 macOS 自带。**
- If `Mac/builder/steamcmd.sh` is missing during a real upload, the Mac uploader automatically downloads and extracts SteamCMD into the configured `steamCmdPath`. You can also install it explicitly with `Mac/InstallSteamCMD.sh`.<br/>**真实上传时如果缺少 `Mac/builder/steamcmd.sh`，Mac 上传器会自动下载并解压到配置中的 `steamCmdPath`；也可以手动运行 `Mac/InstallSteamCMD.sh` 安装。**
- On Apple Silicon, install Rosetta 2 if the downloaded SteamCMD cannot start: `softwareupdate --install-rosetta --agree-to-license`.<br/>**在 Apple Silicon 上，如果下载的 SteamCMD 无法启动，请先安装 Rosetta 2：`softwareupdate --install-rosetta --agree-to-license`。**
- Run a Windows `.bat` launcher or double-click a macOS `.command` launcher: `Mac/UploadSteamBuild.zh-CN.command` or `Mac/UploadSteamBuild.en-US.command`.<br/>**Windows 运行 `.bat` 启动器；macOS 双击 `.command` 启动器：`Mac/UploadSteamBuild.zh-CN.command` 或 `Mac/UploadSteamBuild.en-US.command`。**
- If a config file does not exist, the selected workflow creates a blank template and stops so you can fill in real values.<br/>**如果所选流程的配置文件不存在，脚本会自动创建空模板并停止，等待你填写真实配置。**
- Steam username is entered at runtime, while password and Steam Guard are handled directly by SteamCMD in the terminal.<br/>**Steam 用户名在运行时输入，密码和 Steam Guard 由 SteamCMD 在终端中直接处理。**
- If SteamCMD reports an invalid password or failed Steam Guard code, the uploader pauses and lets you press Enter to retry the login; type `q` to cancel. Build/upload errors are reported immediately without login retries.<br/>**如果 SteamCMD 报告密码错误或 Steam Guard 验证失败，上传器会暂停并允许按 Enter 重试登录；输入 `q` 取消。构建/上传错误会直接报告，不会重复登录。**

## Configuration

The shared release configuration is stored in `Win/config/games.json` and copied to `Mac/config/games.json`, so maintainers use the same AppIDs, DepotIDs, and entry names. The Mac copy uses the macOS SteamCMD path. Keep credentials and machine-specific overrides in ignored local files, never in the shared configs.<br/>**团队共用的发行配置保存在 `Win/config/games.json`，并复制到 `Mac/config/games.json`，确保维护者使用一致的 AppID、DepotID 和入口名称。Mac 版本使用 macOS SteamCMD 路径。账号凭据和机器专用覆盖配置应放在已忽略的本地文件中，绝不能写入共享配置。**
Each game should define separate `full` and `demo` release groups so the script can resolve the correct AppID, depot IDs, and target entry names from the package name.<br/>**每个游戏都应分别定义 `full` 和 `demo` 两个发行组，这样脚本才能根据包名解析出正确的 AppID、depot ID 和目标入口文件名。**

Configuration example:<br/>**配置示例：**

```json
"full": {
  "entryNames": {
    "Win": "FactorZoo.exe",
    "Mac": "FactorZoo.app"
  },
  "appId": "123456",
  "depots": {
    "Win": "123457",
    "Mac": "123458"
  }
}
```

## Package Rules

Only `.zip` archives are supported.<br/>**当前只支持 `.zip` 压缩包。**
- Use one of these file name formats: `Win_GameName_1.2.3.zip`, `Mac_GameName_1.2.3.zip`, `Win_GameName_1.2.3_Demo.zip`, or `Mac_GameName_1.2.3_Demo.zip`.<br/>**压缩包文件名必须使用以下格式之一：`Win_GameName_1.2.3.zip`、`Mac_GameName_1.2.3.zip`、`Win_GameName_1.2.3_Demo.zip`、`Mac_GameName_1.2.3_Demo.zip`。**
- The `GameName` part must match a key under `games` in the selected workflow's `config/games.json`.<br/>**其中的 `GameName` 必须与所选流程 `config/games.json` 里 `games` 下的键一致。**
- Create the zip from the project root directory, not from its parent directory, so the executable or app bundle is available at the expected top level after extraction.<br/>**请从项目根目录打 zip，不要从它的父目录打包，否则解压后可执行文件或 app 包不会出现在预期层级。**
- The selected workflow extracts Windows packages into `<Platform>/workspace/content/<AppID>/win_build` and macOS packages into `<Platform>/workspace/content/<AppID>/mac_build`.<br/>**所选流程会把 Windows 包解压到 `<Platform>/workspace/content/<AppID>/win_build`，把 macOS 包解压到 `<Platform>/workspace/content/<AppID>/mac_build`。**

## Entry Validation

After extraction, the script validates and, when possible, fixes the configured entry names before generating VDF files.<br/>**解压完成后，脚本会先校验配置要求的入口名称，并在可自动修正时完成修正，然后再生成 VDF 文件。**

- If a Windows executable is renamed, a matching `<OldName>_Data` or `<OldName>_Date` directory is renamed to the new prefix too.<br/>**如果 Windows 可执行文件被改名，对应的 `<旧名>_Data` 或 `<旧名>_Date` 目录也会一起改成新前缀。**
- If a macOS app bundle is renamed, the script also renames `Contents/MacOS/<OldName>` and updates `Info.plist` `CFBundleExecutable` when present.<br/>**如果 macOS app 包被改名，脚本也会同步改名 `Contents/MacOS/<旧名>`，并在存在时更新 `Info.plist` 中的 `CFBundleExecutable`。**
- For Electron apps, the same rename is applied to every `Contents/Frameworks/<Name> Helper*.app` bundle, its `Contents/MacOS` executable, and its helper plist name fields.<br/>**对于 Electron 应用，脚本还会同步重命名 `Contents/Frameworks/<Name> Helper*.app`、内部 `Contents/MacOS` 可执行文件及 Helper plist 的名称字段。**
- If there is exactly one valid candidate with the wrong name, the script renames it automatically; if there are zero or multiple candidates, the task stops for manual fixing.<br/>**如果只有一个有效候选但名字不对，脚本会自动改名；如果候选为 0 个或多个，当前任务会停止，等待人工修复。**

## Usage

Double-click one of these launchers to start the guided workflow:<br/>**双击以下任一入口即可启动引导式上传流程：**

```text
Win/UploadSteamBuild.zh-CN.bat
Win/UploadSteamBuild.en-US.bat
Mac/UploadSteamBuild.zh-CN.command
Mac/UploadSteamBuild.en-US.command
```

Place one or more zip packages into the selected workflow's `inbox`, return to the terminal window, and press Enter to scan them.<br/>**把一个或多个 zip 包放进所选流程的 `inbox`，回到终端窗口后按回车即可开始扫描。**

If a package name is invalid, the script lists the bad files and waits for you to rename or remove them before continuing.<br/>**如果压缩包命名不合法，脚本会列出问题文件并等待你改名或移除后再继续。**

After a real upload succeeds, any source zip that came from the selected workflow's `inbox` is moved to its `inbox/done`, and the `done` directory is created automatically when needed.<br/>**真实上传成功后，凡是来自所选流程 `inbox` 的源 zip 都会被移动到对应的 `inbox/done`，如果 `done` 目录不存在则自动创建。**

## Upload Behavior

Packages are queued separately per platform package. A matching Win and Mac pair for the same game, release type, version, and AppID becomes two sequential Steam app build submissions instead of one merged build.<br/>**每个平台压缩包都会单独进入队列。即使同一个游戏、同一发行类型、同一版本、同一 AppID 同时提供了 Win 和 Mac 包，也会拆成两个连续的 Steam app build 提交，而不是合并成一次。**

Queued tasks run one after another in order. Different AppIDs are still separated, and the same AppID may appear more than once when multiple platform packages are submitted together.<br/>**队列中的任务会按顺序逐个执行。不同 AppID 仍然会拆开处理，而当多个平台包一起提交时，同一个 AppID 也可能在队列里出现多次。**

SteamCMD uploads the extracted `<Platform>/workspace/content/<AppID>` tree through generated VDF files, so the original zip is only an input archive and is never repackaged during upload.<br/>**SteamCMD 通过生成的 VDF 直接上传 `<Platform>/workspace/content/<AppID>` 下的解压内容树，因此原始 zip 只是输入源，上传过程中不会被重新打包。**
