# Steam Windows Upload Tool / Steam Windows 上传工具

English: This repository contains the Windows SteamCMD upload workflow.

中文：这个仓库用于维护 Windows 版 SteamCMD 上传流程。

## Overview / 概述

English: The current repository focuses on the Windows workflow under `Win/`. It scans packages from `Win/inbox`, validates package names, extracts content into `Win/workspace`, fixes entry names when possible, generates VDF files, and uploads through SteamCMD.

中文：当前仓库主要提供 `Win/` 下的 Windows 上传方案。它会从 `Win/inbox` 扫描压缩包，校验命名，解压到 `Win/workspace`，在可自动修正时修正入口文件名，生成 VDF，然后通过 SteamCMD 上传。

## First-Time Setup / 首次配置

1. English: Put the Windows SteamCMD executable at `Win/builder/steamcmd.exe`.
   中文：把 Windows 版 SteamCMD 放到 `Win/builder/steamcmd.exe`。
2. English: Run the script once. If `Win/config/games.json` does not exist, the script creates it automatically.
   中文：先运行一次脚本。如果 `Win/config/games.json` 不存在，脚本会自动创建它。
3. English: Edit `Win/config/games.json`.
   中文：编辑 `Win/config/games.json`。
4. English: Fill each release group's `entryNames.Win`, `entryNames.Mac`, `appId`, `depots.Win`, and `depots.Mac`.
   中文：填写每个发行组的 `entryNames.Win`、`entryNames.Mac`、`appId`、`depots.Win` 和 `depots.Mac`。
5. English: Leave `setLive` empty unless you intentionally want SteamCMD to set a beta branch live.
   中文：除非你明确要自动切某个 beta 分支，否则让 `setLive` 保持为空。
6. English: Steam username is entered at runtime. Password and Steam Guard are handled by SteamCMD in the terminal.
   中文：Steam 用户名在运行时输入，密码和 Steam Guard 由 SteamCMD 在终端中处理。

English: `Win/config/games.json` is intentionally ignored by git because it may contain private AppIDs and DepotIDs. If the file exists but misses expected fields, the script writes those fields back with empty values and asks you to complete them.

中文：`Win/config/games.json` 故意被 git 忽略，因为里面可能包含真实 AppID 和 DepotID。如果文件存在但缺少预期字段，脚本会自动补空字段并要求你补全。

## Config Fields / 配置字段

English: `setLive` is the Steam beta branch to assign after upload. Leave it empty to upload only.

中文：`setLive` 表示上传后要自动设置的 Steam beta 分支。留空表示只上传，不自动切分支。

English: `steamCmdPath` is the path to `steamcmd.exe`. Relative paths are resolved from `Win/`.

中文：`steamCmdPath` 是 `steamcmd.exe` 的路径。相对路径会以 `Win/` 为基准解析。

English: `games` is a map keyed by the game name used in package filenames. For `Win_FactorZoo_0.0.0_Demo.zip`, the game key is `FactorZoo`.

中文：`games` 是以压缩包文件名中的游戏名为键的映射。例如 `Win_FactorZoo_0.0.0_Demo.zip` 对应的键是 `FactorZoo`。

Example / 示例：

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

English: Each game has two release groups:

- `full`: used when the package filename does not end with `_Demo`.
- `demo`: used when the package filename ends with `_Demo`.

中文：每个游戏有两个发行组：

- `full`：用于文件名不带 `_Demo` 的正式版。
- `demo`：用于文件名带 `_Demo` 的 Demo 版。

English: Only configure release groups that actually exist. If a package points to a missing group, the script stops before extraction or upload.

中文：只配置实际存在的发行组。如果压缩包指向缺失的发行组，脚本会在解压和上传前停止。

## Package Naming / 压缩包命名

English: Only `.zip` is supported.

中文：当前只支持 `.zip`。

```text
Win_GameName_1.2.3.zip
Mac_GameName_1.2.3.zip
Win_GameName_1.2.3_Demo.zip
Mac_GameName_1.2.3_Demo.zip
```

English: The script extracts Windows packages into `Win/workspace/content/<AppID>/win_build` and macOS packages into `Win/workspace/content/<AppID>/mac_build`.

中文：脚本会把 Windows 包解压到 `Win/workspace/content/<AppID>/win_build`，把 macOS 包解压到 `Win/workspace/content/<AppID>/mac_build`。

## Entry Validation / 入口校验

English: After extraction, the script checks the configured entry name.

中文：解压完成后，脚本会按配置检查入口名称。

- English: Windows entry must match `Win/config/games.json`.
  中文：Windows 入口必须匹配 `Win/config/games.json`。
- English: Crash handler executables such as `UnityCrashHandler64.exe` are ignored when selecting the Windows entry.
  中文：选择 Windows 主入口时会跳过 `UnityCrashHandler64.exe` 这类崩溃处理程序。
- English: If the Windows entry is renamed, a matching `<OldName>_Data` or `<OldName>_Date` folder is renamed too.
  中文：如果 Windows 入口被改名，对应的 `<旧名>_Data` 或 `<旧名>_Date` 目录也会一起改名。
- English: macOS entry must match `Win/config/games.json`.
  中文：macOS 入口也必须匹配 `Win/config/games.json`。
- English: If the macOS app is renamed, `Contents/MacOS/<OldName>` and `Info.plist` `CFBundleExecutable` are updated too.
  中文：如果 macOS app 被改名，`Contents/MacOS/<旧名>` 和 `Info.plist` 中的 `CFBundleExecutable` 也会同步更新。
- English: If there is exactly one valid candidate with a different name, it is renamed automatically.
  中文：如果只有一个有效候选但名字不一致，脚本会自动改名。
- English: If there are zero or multiple candidates, the upload stops for manual fixing.
  中文：如果候选为 0 个或多个，上传会停止，等待人工处理。

## Usage / 使用方法

Double-click / 双击入口：

```text
Win/UploadSteamBuild.zh-CN.bat
Win/UploadSteamBuild.en-US.bat
```

English: The script opens `Win/inbox`. Copy one or more zip packages into that folder, return to the terminal window, and press Enter. The script scans every `.zip` in `Win/inbox`.

中文：脚本会自动打开 `Win/inbox`。把一个或多个 zip 包复制进去，回到终端窗口按回车，脚本会扫描 `Win/inbox` 中的所有 `.zip`。

English: If any package name does not match the required rule, the script lists the bad files and waits. Rename or remove them in `Win/inbox`, then press Enter again.

中文：如果有压缩包命名不符合规则，脚本会列出这些文件并等待。你需要在 `Win/inbox` 中改名或移除，再按回车继续。

English: After a real upload succeeds, any source zip that came from `Win/inbox` is moved to `Win/inbox/done`. The script creates `Win/inbox/done` automatically when needed.

中文：真实上传成功后，来自 `Win/inbox` 的源 zip 会被移动到 `Win/inbox/done`。如果 `done` 不存在，脚本会自动创建。

English: If the matching config is missing, empty, or still a placeholder, edit `Win/config/games.json`, press Enter, and the tool reloads the config before moving on.

中文：如果匹配的配置缺失、为空，或者还只是占位值，请编辑 `Win/config/games.json`，然后按回车，工具会重新加载配置再继续。

Preview only / 仅预览：

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -Language zh-CN -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip -PlanOnly
```

Use a different config file / 使用其他配置文件：

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -ConfigPath .\Win\config\games.local.json
```

Generate workspace and VDF files without uploading / 只生成 workspace 和 VDF，不上传：

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip -DryRun
```

Run the real upload / 执行真实上传：

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip
```

Run the real upload with the username prefilled / 预填 Steam 用户名执行真实上传：

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip -SteamUser your_steam_username
```

## Workspace / 工作目录说明

English: `Win/workspace` is a disposable working directory. It stores copied archives, extracted content, generated VDF files, and upload output logs. Deleting everything inside `Win/workspace` does not break the project itself.

中文：`Win/workspace` 是可丢弃的工作目录。它里面保存的是复制后的压缩包、解压内容、生成的 VDF，以及上传输出日志。把 `Win/workspace` 里的内容全部删掉，不会破坏项目本身。

English: On the next run, the script recreates the required subdirectories automatically.

中文：下次运行时，脚本会自动重新创建需要的子目录。

English: Do not delete `Win/UploadSteamBuild.ps1`, `Win/config/games.json`, `Win/inbox`, or the SteamCMD files under `Win/builder` if you still want to run uploads.

中文：但如果你还要继续上传，请不要删除 `Win/UploadSteamBuild.ps1`、`Win/config/games.json`、`Win/inbox`，以及 `Win/builder` 下的 SteamCMD 文件。

## Upload Behavior / 上传行为

English: Packages with the same game, release type, version, and AppID are merged into one Steam app build. A matching Win and Mac pair uploads in one app build with two depots.

中文：相同游戏、相同发行类型、相同版本和相同 AppID 的包会被合并成一个 Steam app build。匹配的 Win 和 Mac 包会在同一个 app build 中一起上传，并使用两个 depot。

English: Different AppIDs become separate queued tasks and run one after another.

中文：不同 AppID 会变成独立任务，按顺序排队执行。

English: SteamCMD uploads the extracted `Win/workspace/content/<AppID>` tree through generated VDF files. The original zip is only an input archive, so the workflow does not repackage the zip and does not add another directory layer.

中文：SteamCMD 通过生成的 VDF 直接上传 `Win/workspace/content/<AppID>` 下的解压内容树。原始 zip 只是输入源，所以这个流程不会重新打包 zip，也不会额外增加一层目录嵌套。