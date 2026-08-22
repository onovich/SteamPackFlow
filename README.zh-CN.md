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

### 发布使用

用途：扫描对应平台的 `inbox`，校验并整理构建包、生成 VDF，然后通过 SteamCMD 上传。每次需要发布新构建时操作。

发布前，请将构建 ZIP 放入 `Mac/inbox` 或 `Win/inbox`，检查对应的 `config/games.json`，然后根据所需语言双击启动文件：

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
