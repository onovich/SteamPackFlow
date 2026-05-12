# SteamPackFlow

SteamPackFlow is a SteamCMD upload workflow for validating package names, normalizing entry files, generating VDF files, and uploading builds.<br/>**SteamPackFlow 是一个 SteamCMD 上传工作流，用于校验压缩包命名、规范化入口文件、生成 VDF 文件并上传构建。**

## Overview

This repository currently distributes the upload workflow under `Win/` and is designed to make batch uploads with SteamCMD easier on Windows.<br/>**当前仓库实际分发的是 `Win/` 下的上传流程，设计目标是在 Windows 系统上更方便地使用 SteamCMD 进行批量上传。**

It scans packages from `Win/inbox`, validates file names, extracts content into `Win/workspace`, fixes entry names, groups uploads by AppID, and submits builds through SteamCMD.<br/>**它会从 `Win/inbox` 扫描压缩包，校验文件命名，解压到 `Win/workspace`，修正入口名称，按 AppID 分组上传，并通过 SteamCMD 提交构建。**

## Setup

- Put the Windows SteamCMD executable at `Win/builder/steamcmd.exe`.<br/>**把 Windows 版 SteamCMD 放到 `Win/builder/steamcmd.exe`。**
- Run either `Win/UploadSteamBuild.zh-CN.bat` for Chinese users or `Win/UploadSteamBuild.en-US.bat` for English users to initialize the workflow.<br/>**先运行一次 `Win/UploadSteamBuild.zh-CN.bat`（中文用户选择）或 `Win/UploadSteamBuild.en-US.bat` （英文用户选择）来初始化流程。**
- If `Win/config/games.json` does not exist, the script creates it automatically and stops so you can fill in real values.<br/>**如果 `Win/config/games.json` 不存在，脚本会自动创建它并停止，等待你填写真实配置。**
- Steam username is entered at runtime, while password and Steam Guard are handled directly by SteamCMD in the terminal.<br/>**Steam 用户名在运行时输入，密码和 Steam Guard 由 SteamCMD 在终端中直接处理。**

## Configuration

The main local configuration file is `Win/config/games.json`, and it is intentionally ignored by git because it may contain private AppIDs and DepotIDs.<br/>**主要的本地配置文件是 `Win/config/games.json`，它被故意排除在 git 之外，因为其中可能包含私有 AppID 和 DepotID。**
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
- The `GameName` part must match a key under `games` in `Win/config/games.json`.<br/>**其中的 `GameName` 必须与 `Win/config/games.json` 里 `games` 下的键一致。**
- Create the zip from the project root directory, not from its parent directory, so the executable or app bundle is available at the expected top level after extraction.<br/>**请从项目根目录打 zip，不要从它的父目录打包，否则解压后可执行文件或 app 包不会出现在预期层级。**
- The script extracts Windows packages into `Win/workspace/content/<AppID>/win_build` and macOS packages into `Win/workspace/content/<AppID>/mac_build`.<br/>**脚本会把 Windows 包解压到 `Win/workspace/content/<AppID>/win_build`，把 macOS 包解压到 `Win/workspace/content/<AppID>/mac_build`。**

## Entry Validation

After extraction, the script validates and, when possible, fixes the configured entry names before generating VDF files.<br/>**解压完成后，脚本会先校验配置要求的入口名称，并在可自动修正时完成修正，然后再生成 VDF 文件。**

- If a Windows executable is renamed, a matching `<OldName>_Data` or `<OldName>_Date` directory is renamed to the new prefix too.<br/>**如果 Windows 可执行文件被改名，对应的 `<旧名>_Data` 或 `<旧名>_Date` 目录也会一起改成新前缀。**
- If a macOS app bundle is renamed, the script also renames `Contents/MacOS/<OldName>` and updates `Info.plist` `CFBundleExecutable` when present.<br/>**如果 macOS app 包被改名，脚本也会同步改名 `Contents/MacOS/<旧名>`，并在存在时更新 `Info.plist` 中的 `CFBundleExecutable`。**
- If there is exactly one valid candidate with the wrong name, the script renames it automatically; if there are zero or multiple candidates, the task stops for manual fixing.<br/>**如果只有一个有效候选但名字不对，脚本会自动改名；如果候选为 0 个或多个，当前任务会停止，等待人工修复。**

## Usage

Double-click one of these launchers to start the guided workflow:<br/>**双击以下任一入口即可启动引导式上传流程：**

```text
Win/UploadSteamBuild.zh-CN.bat
Win/UploadSteamBuild.en-US.bat
```

Place one or more zip packages into `Win/inbox`, return to the terminal window, and press Enter to scan them.<br/>**把一个或多个 zip 包放进 `Win/inbox`，回到终端窗口后按回车即可开始扫描。**

If a package name is invalid, the script lists the bad files and waits for you to rename or remove them before continuing.<br/>**如果压缩包命名不合法，脚本会列出问题文件并等待你改名或移除后再继续。**

After a real upload succeeds, any source zip that came from `Win/inbox` is moved to `Win/inbox/done`, and the `done` directory is created automatically when needed.<br/>**真实上传成功后，凡是来自 `Win/inbox` 的源 zip 都会被移动到 `Win/inbox/done`，如果 `done` 目录不存在则会自动创建。**

## Upload Behavior

Packages with the same game, release type, version, and AppID are merged into one Steam app build, so a matching Win and Mac pair uploads together under one AppID with two depots.<br/>**相同游戏、相同发行类型、相同版本和相同 AppID 的包会被合并成一个 Steam app build，因此匹配的 Win 和 Mac 包会在同一个 AppID 下以两个 depot 一起上传。**

Different AppIDs become separate queued tasks and run one after another.<br/>**不同 AppID 会拆成独立任务，并按顺序排队执行。**

SteamCMD uploads the extracted `Win/workspace/content/<AppID>` tree through generated VDF files, so the original zip is only an input archive and is never repackaged during upload.<br/>**SteamCMD 通过生成的 VDF 直接上传 `Win/workspace/content/<AppID>` 下的解压内容树，因此原始 zip 只是输入源，上传过程中不会被重新打包。**