# Steam Windows Upload Tool

This directory contains the Windows upload workflow for SteamCMD.

## First-time setup

1. Put the Windows SteamCMD executable at `Win/builder/steamcmd.exe`.
2. Run the script once, or copy `Win/config/games.example.json` to `Win/config/games.json`.
3. Edit `Win/config/games.json`.
4. Fill each game's `appId`, `Win` depot ID, and `Mac` depot ID for the release types that exist.
5. Keep `setLive` as `test` until you intentionally want to publish to another branch.
6. Steam username is entered at runtime. Password and Steam Guard code are handled by SteamCMD in the terminal.

`games.example.json` is a small reference. `games.json` is the file used by the script and is intentionally ignored by git because it can contain private AppIDs and DepotIDs. If `games.json` does not exist, the script creates a blank template and stops so you can fill it in.

## Config fields

`setLive` is the Steam branch that the uploaded build should be assigned to. The current default is `test`, matching the existing Mac workflow. Leave it empty if you want SteamCMD to upload the build without setting a live branch.

`steamCmdPath` is the path to `steamcmd.exe`. Relative paths are resolved from the `Win` directory, so `builder\\steamcmd.exe` means `Win/builder/steamcmd.exe`.

`games` is a map keyed by the game name used in package filenames. For `Win_FactorZoo_0.0.0_Demo.zip`, the game key is `FactorZoo`.

Each game has two release groups:

- `full`: used when the package filename does not end with `_Demo`.
- `demo`: used when the package filename ends with `_Demo`.

Only configure release groups that actually exist, but the uploaded package must have a matching group. For example, if a user uploads `Win_FactorZoo_1.0.0.zip`, the script requires `games.FactorZoo.full`; if only `games.FactorZoo.demo` exists, it stops before extracting or uploading and asks the user to complete the config.

Each release group contains:

- `appId`: the Steam AppID for that exact game and release type. Demo and full releases usually have different AppIDs.
- `depots.Win`: the Windows depot ID for that AppID.
- `depots.Mac`: the macOS depot ID for that AppID.

Steam account information is intentionally not stored in `games.json`. The script asks for the Steam username during real uploads, then SteamCMD asks for password and Steam Guard code as needed.

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
UploadSteamBuild.zh-CN.bat
UploadSteamBuild.en-US.bat
```

`UploadSteamBuild.bat` is kept as a Chinese default entry for compatibility.

The script opens `Win/inbox`. Copy one or more zip packages into that folder, return to the terminal window, and press Enter. The script scans every `.zip` in `Win/inbox`.

If any package name does not match the required rule, the script lists the bad files and waits. Rename or remove them in `Win/inbox`, then press Enter again. It will not continue to extraction or upload until every package name is valid.

Preview only:

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -Language zh-CN -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip -PlanOnly
```

Use a different config file:

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -ConfigPath .\Win\config\games.local.json
```

Generate workspace and VDF files without uploading:

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip -DryRun
```

Run the real upload:

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip,.\Build\Mac_FactorZoo_0.0.0_Demo.zip
```

Run the real upload with the username prefilled:

```powershell
powershell -ExecutionPolicy Bypass -File .\Win\UploadSteamBuild.ps1 -PackagePath .\Build\Win_FactorZoo_0.0.0_Demo.zip -SteamUser your_steam_username
```

## Upload behavior

Packages with the same game, release type, version, and AppID are merged into one Steam app build. That means a matching Win and Mac pair will upload in one app build with two depots.

Different AppIDs become separate queued tasks and run one after another.
