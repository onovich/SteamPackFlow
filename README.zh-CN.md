# SteamPackFlow

[English](README.md)

跨 Windows/macOS 的 SteamCMD 打包上传流程，负责校验包名、生成 VDF 和上传构建。

![SteamPackFlow 封面](docs/cover.png)

## 项目包含什么

- 支持 Windows 与 macOS。
- 生成 VDF。
- 通过 SteamCMD 上传。

## 快速开始

直接双击下面列出的启动文件即可，无需在终端中输入命令。

### 首次安装

用途：在新电脑上将 SteamCMD 安装到对应平台的 `builder` 目录；SteamCMD 缺失或损坏时也可用它恢复。通常只需操作一次。

- macOS：双击 `Mac/InstallSteamCMD.command`。
- Windows：双击 `Win/InstallSteamCMD.bat`。

发布启动器检测到 SteamCMD 缺失时会自动安装，因此首次发布前单独安装是可选步骤。

### 配置游戏

编辑 `Win/config/games.json` 或 `Mac/config/games.json`，在 `games` 下添加游戏：

```json
{
  "games": {
    "MyGame": {
      "full": { "entryNames": { "Win": "MyGame.exe", "Mac": "MyGame.app" }, "appId": "APP_ID", "depots": { "Win": "WIN_DEPOT_ID", "Mac": "MAC_DEPOT_ID" } },
      "demo": { "entryNames": { "Win": "MyGame.exe", "Mac": "MyGame.app" }, "appId": "DEMO_APP_ID", "depots": { "Win": "DEMO_WIN_DEPOT_ID", "Mac": "DEMO_MAC_DEPOT_ID" } }
    }
  }
}
```

`entryNames` 是 Steam 启动用的 `.exe`/`.app`，AppID 和 DepotID 从 Steamworks 获取。游戏键只能使用字母和数字，并且必须与 ZIP 文件名一致：`Win_MyGame_1.2.3_Demo.zip` 使用 `demo`，不带 `_Demo` 时使用 `full`。`steamCmdPath` 通常无需修改；`setLive` 留空表示只上传、不自动上线。不要在配置中保存 Steam 用户名、密码或 API Key。

### 发布使用

用途：扫描对应平台的 `inbox`，校验并整理构建包、生成 VDF，然后通过 SteamCMD 上传。每次需要发布新构建时操作。

将构建 ZIP 放入 `Mac/inbox` 或 `Win/inbox`，然后根据所需语言双击启动文件：

- macOS 中文：`Mac/UploadSteamBuild.zh-CN.command`
- macOS 英文：`Mac/UploadSteamBuild.en-US.command`
- Windows 中文：`Win/UploadSteamBuild.zh-CN.bat`
- Windows 英文：`Win/UploadSteamBuild.en-US.bat`

## 仓库结构

- `Mac/` — macOS 流程。
- `Win/` — Windows 流程。

## 当前状态

仓库已经包含与上述用途对应的实现和项目材料。当前仓库没有自动化测试，评估时请在目标环境中直接运行。

## 许可证

当前仓库未包含开源许可证。
