# Steam Windows Upload Tool

This directory contains the Windows upload workflow for SteamCMD.

## First-time setup

1. Put the Windows SteamCMD executable at `Win/builder/steamcmd.exe`.
2. Edit `Win/config/games.json`.
3. Fill each game's `appId`, `Win` depot ID, and `Mac` depot ID for both `full` and `demo` releases.
4. Keep `setLive` as `test` until you intentionally want to publish to another branch.

`games.example.json` is a small reference. `games.json` is the file used by the script.

## Package naming

Only `.zip` is supported.

```text
Win_GameName_1.2.3.zip
Mac_GameName_1.2.3.zip
Win_GameName_1.2.3_Demo.zip
Mac_GameName_1.2.3_Demo.zip
```

The script extracts Windows packages into `workspace/content/<AppID>/win_build` and macOS packages into `workspace/content/<AppID>/mac_build`.

After extraction, it checks the entry name:

- Windows entry must be `game.exe`.
- macOS entry must be `game.app`.
- If there is exactly one candidate with another name, it is renamed automatically.
- If there are zero or multiple candidates, the upload stops so the package can be fixed manually.

## Usage

Double-click:

```text
UploadSteamBuild.bat
```

Then drag one or more zip packages into the terminal window and press Enter.

Preview only:

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip -PlanOnly
```

Generate workspace and VDF files without uploading:

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip -DryRun
```

Run the real upload:

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip
```

## Upload behavior

Packages with the same game, release type, version, and AppID are merged into one Steam app build. That means a matching Win and Mac pair will upload in one app build with two depots.

Different AppIDs become separate queued tasks and run one after another.

