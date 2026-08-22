# SteamPackFlow

[简体中文](README.zh-CN.md)

Validate, describe, and upload Steam builds.

![SteamPackFlow cover](docs/cover.png)

## What it includes

- Windows + macOS.
- VDF generation.
- SteamCMD upload.

## Getting started

Use the double-click launchers below; no terminal commands are required.

### First-time setup

Purpose: install SteamCMD into the platform's `builder` directory on a new machine, or restore it if it is missing or damaged. You normally need this step only once.

- macOS: double-click `Mac/InstallSteamCMD.command`.
- Windows: double-click `Win/InstallSteamCMD.bat`.

The upload launchers automatically install SteamCMD when it is missing, so this standalone setup step is optional before the first upload.

### Publishing a build

Purpose: scan the platform `inbox`, validate and prepare build packages, generate VDF files, and upload the build through SteamCMD. Use this step whenever you want to publish a build.

Before publishing, place the build ZIP in `Mac/inbox` or `Win/inbox`, review the corresponding `config/games.json`, and then double-click the launcher for the desired language:

- macOS Chinese: `Mac/UploadSteamBuild.zh-CN.command`
- macOS English: `Mac/UploadSteamBuild.en-US.command`
- Windows Chinese: `Win/UploadSteamBuild.zh-CN.bat`
- Windows English: `Win/UploadSteamBuild.en-US.bat`

## Repository map

- `Mac/` — macOS workflow.
- `Win/` — Windows workflow.

## Status

The repository contains the implementation and project material described above. No automated tests are currently present; evaluate it by running the project in the target environment.

## License

No open-source license is currently included in this repository.
