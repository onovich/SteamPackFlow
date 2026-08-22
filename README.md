# SteamPackFlow

[简体中文](README.zh-CN.md)

Validate, describe, and upload Steam builds.

![SteamPackFlow cover](docs/cover.png)

## What it includes

- Windows + macOS.
- VDF generation.
- SteamCMD upload.

## Getting started

Run these commands from the repository root.

### First-time setup

Purpose: install SteamCMD into the platform's `builder` directory on a new machine, or restore it if it is missing or damaged. You normally need this command only once.

macOS:

```bash
bash Mac/InstallSteamCMD.sh
```

Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Win\InstallSteamCMD.ps1
```

You can also double-click `Win/InstallSteamCMD.bat`. The upload scripts automatically install SteamCMD when it is missing, so the standalone setup step is optional before the first upload.

### Publishing a build

Purpose: scan the platform `inbox`, validate and prepare build packages, generate VDF files, and upload the build through SteamCMD. Use this command whenever you want to publish a build.

Before publishing, place the build ZIP in `Mac/inbox` or `Win/inbox` and review the corresponding `config/games.json`.

macOS:

```bash
bash Mac/UploadSteamBuild.sh
```

Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1
```

## Repository map

- `Mac/` — macOS workflow.
- `Win/` — Windows workflow.

## Status

The repository contains the implementation and project material described above. No automated tests are currently present; evaluate it by running the project in the target environment.

## License

No open-source license is currently included in this repository.
