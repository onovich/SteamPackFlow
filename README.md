# SteamPackFlow

[简体中文](README.zh-CN.md)

Validate, describe, and upload Steam builds.

![SteamPackFlow cover](docs/cover.png)

## What it includes

- Windows + macOS.
- VDF generation.
- SteamCMD upload.

## Getting started

Choose the script for the target platform and review its configuration block before running it:

- `Mac/InstallSteamCMD.sh`

- `Mac/UploadSteamBuild.sh`

- `Win/InstallSteamCMD.bat` or `Win/InstallSteamCMD.ps1`

- `Win/UploadSteamBuild.ps1`

Both uploaders install SteamCMD into their configured default `builder` directory when it is missing. The standalone installers are useful for preparing a machine before the first upload.

## Repository map

- `Mac/` — macOS workflow.
- `Win/` — Windows workflow.

## Status

The repository contains the implementation and project material described above. No automated tests are currently present; evaluate it by running the project in the target environment.

## License

No open-source license is currently included in this repository.
