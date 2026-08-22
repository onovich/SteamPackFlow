# Electron Web → Steam

A portable, agent-independent workflow for turning a built web frontend into Steam-ready Electron payloads for Windows and macOS.

This directory is intentionally self-contained. A human or any coding agent can follow `SKILL.md`; the scripts only require Node.js/npm, Electron, electron-builder, and the native operating-system tools used by the target platform. Nothing depends on a particular agent runtime, metadata format, or plugin system.

## What it produces

| Platform | Steam payload | CI/handoff archive |
| --- | --- | --- |
| Windows | An unpacked directory containing `Game.exe`, `resources/app.asar`, and the Electron runtime | `Win_<Game>_<Version>[_Demo].zip`, with the directory contents at ZIP root |
| macOS | A complete `Game.app` bundle | `Mac_<Game>_<Version>[_Demo].zip`, with the `.app` at ZIP root |

For Steam, “Windows `.exe`” means the entry executable inside the complete unpacked app. A lone installer executable is not a Steam-ready payload.

## Quick start

Copy this whole directory into any repository, for example `tools/electron-web-steam-packager`, then run:

```bash
node tools/electron-web-steam-packager/scripts/scaffold.mjs \
  --project-dir . \
  --web-root dist \
  --app-name "My Game" \
  --app-id com.example.mygame \
  --executable-name MyGame
```

Build on native runners:

```powershell
node tools/electron-web-steam-packager/scripts/build.mjs --project-dir . --platform win --arch x64
```

```bash
node tools/electron-web-steam-packager/scripts/build.mjs --project-dir . --platform mac --arch universal
```

The build script installs dependencies unless `--skip-install` is supplied, runs `npm run build` unless `--skip-web-build` is supplied, creates an unpacked app with electron-builder, and then verifies the Steam artifact contract.

The scaffold has reviewed dependency defaults, accepts explicit `--electron-version` and `--builder-version` overrides, and preserves versions already declared by the project. Commit the generated lockfile so CI does not resolve a different toolchain later.

Use `node <script> --help` (or PowerShell `Get-Help`) for all options. Start CI work from `assets/github-actions/electron-steam-build.yml` and adapt only the clearly marked project values.

## Recommended repository layout

```text
project/
  electron/main.cjs
  dist/                         # generated web frontend
  electron-builder.steam.json
  tools/electron-web-steam-packager/
  .github/workflows/electron-steam-build.yml
```

Commit the workflow and packaging configuration. Do not commit `node_modules`, `dist-electron`, `.steam-build`, Steam credentials, or generated archives.

## Release invariant

The same release version, release kind (`full` or `demo`), executable name, and platform set must flow from build to verification to packaging to Steam upload. If any of those values is missing or changes between stages, fail before upload.

See `references/artifact-contract.md` for exact pass/fail rules and `references/ci-cd.md` for the CI boundary.
