# SteamPackFlow

[English](README.md)

跨 Windows/macOS 的 SteamCMD 打包上传流程，负责校验包名、生成 VDF 和上传构建。

![SteamPackFlow 封面](docs/cover.png)

## 项目包含什么

- 支持 Windows 与 macOS。
- 生成 VDF。
- 通过 SteamCMD 上传。

## 快速开始

根据目标平台选择仓库内的脚本，并先阅读脚本顶部的配置项：

- `Mac/InstallSteamCMD.sh`

- `Mac/UploadSteamBuild.sh`

- `Win/InstallSteamCMD.bat` 或 `Win/InstallSteamCMD.ps1`

- `Win/UploadSteamBuild.ps1`

两端上传器都会在 SteamCMD 缺失时自动安装到配置的默认 `builder` 目录。也可以在首次上传前单独运行安装脚本来准备环境。

## 仓库结构

- `Mac/` — macOS 流程。
- `Win/` — Windows 流程。

## 当前状态

仓库已经包含与上述用途对应的实现和项目材料。当前仓库没有自动化测试，评估时请在目标环境中直接运行。

## 许可证

当前仓库未包含开源许可证。
