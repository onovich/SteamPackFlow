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

Purpose: install SteamCMD into the platform's `builder` directory on a new machine, bootstrap its self-update, or restore it if it is missing or damaged. You normally need this step only once.

- macOS: double-click `Mac/InstallSteamCMD.command`.
- Windows: double-click `Win/InstallSteamCMD.bat`.

The upload launchers automatically install SteamCMD when it is missing, so this standalone setup step is optional before the first upload.

### Configure a game

Edit `Win/config/games.json` or `Mac/config/games.json` and add the game under `games`:

```json
{
  "games": {
    "MyGame": {
      "full": { "entryNames": { "Win": "MyGame.exe", "Mac": "MyGame.app" }, "appleTeamId": "APPLE_TEAM_ID", "appId": "APP_ID", "depots": { "Win": "WIN_DEPOT_ID", "Mac": "MAC_DEPOT_ID" } },
      "demo": { "entryNames": { "Win": "MyGame.exe", "Mac": "MyGame.app" }, "appleTeamId": "APPLE_TEAM_ID", "appId": "DEMO_APP_ID", "depots": { "Win": "DEMO_WIN_DEPOT_ID", "Mac": "DEMO_MAC_DEPOT_ID" } }
    }
  }
}
```

`entryNames` is the Steam launch `.exe`/`.app`; copy AppIDs and DepotIDs from Steamworks.
`appleTeamId` is the public 10-character Apple Developer Team ID used to verify signed Mac builds; it
is not a password. The alphanumeric game key must match the ZIP name: `Win_MyGame_1.2.3_Demo.zip`
selects `demo`; without `_Demo`, it selects `full`. Leave `steamCmdPath` unchanged and `setLive` empty
to upload without automatically making the build live. Never store Steam usernames, passwords, or API keys here.

### Publishing a build

Purpose: scan the platform `inbox`, validate and prepare build packages, generate VDF files, and upload the build through SteamCMD. Use this step whenever you want to publish a build.

Place the game ZIP in either platform's `inbox`. Then double-click the launcher in a language you can read:

When creating the ZIP, place all files directly in the ZIP's top-level directory. Do not include their parent folder, because that creates an extra directory level.

- macOS Chinese: `Mac/UploadSteamBuild.zh-CN.command`
- macOS English: `Mac/UploadSteamBuild.en-US.command`
- Windows Chinese: `Win/UploadSteamBuild.zh-CN.bat`
- Windows English: `Win/UploadSteamBuild.en-US.bat`

For a signed Mac app, the configured `.app` and internal executable names must already be correct at build time.

### CI integrations

Automation should invoke the Windows PowerShell uploader with explicit package and Steam user values,
plus `-NonInteractive`. Add `-StrictArtifact` so CI rejects unexpected entry names or an extra ZIP
directory instead of repairing the package. Deployment workflows can lock the expected game, platform,
release, AppID and DepotID and require an empty `setLive`; a mismatch fails before SteamCMD starts.
Use `-Preview` for the first credential and mapping test: SteamCMD creates the manifest and logs but does
not upload content. `config.vdf` is a credential and must be restored from a protected secret, never Git,
an artifact, or a cache.

#### Why Mac publishing was removed from Windows

Windows ZIP handling cannot reliably preserve macOS framework symlinks, Unix executable modes, and
Apple signing/notarization data. Changing any signed `.app` content invalidates its signature, so the
Windows launcher rejects Mac ZIPs. Keep each Mac ZIP unchanged, place it in `Mac/inbox`, and publish
it with the macOS launcher.

## Repository map

- `Mac/` — macOS workflow.
- `Win/` — Windows workflow.

## Status

The repository contains the implementation and project material described above. No automated tests are currently present; evaluate it by running the project in the target environment.

## License

No open-source license is currently included in this repository.
