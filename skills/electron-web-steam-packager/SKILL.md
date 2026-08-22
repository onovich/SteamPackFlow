---
name: electron-web-steam-packager
description: Package a built web frontend as Steam-ready Electron builds for Windows and macOS, verify the depot artifact contract, and prepare CI transport archives without confusing installers with game payloads.
---

# Electron Web Steam Packager

Use this skill when a web game or desktop web app must ship through Steam as an Electron application on Windows and macOS.

The only supported distribution target is Steam. Do not add NSIS, MSI, DMG, AppImage, auto-update, or website-download flows to this workflow.

## Core contract

- Windows: deliver the complete unpacked Electron directory. It contains the requested entry `.exe`, `resources/app.asar` (or `resources/app`), Electron runtime files, and native libraries.
- macOS: deliver one complete `.app` bundle. Preserve its framework links and executable modes.
- ZIP files are transport containers for CI or handoff. They are not the application format and must preserve the artifact layout.
- Reject Windows installers, `.blockmap` files, DMGs, and a lone executable presented as a Steam build.
- Keep full and demo releases explicit. Never infer the Steam app/depot only from a filename after upload begins.

Read [references/artifact-contract.md](references/artifact-contract.md) before changing artifact paths or archive layout. Read [references/ci-cd.md](references/ci-cd.md) when adding or changing automation.

## Workflow

1. Inspect the project before editing:
   - Locate the built web root and its HTML entry file.
   - Inspect `package.json`, lockfiles, existing Electron main process, and existing electron-builder configuration.
   - Identify the exact Steam launch executable name for Windows and bundle/product name for macOS.
   - Identify whether this is a full or demo release and which Steam app/depot receives each platform.

2. Scaffold only what is missing:

   ```text
   node <skill>/scripts/scaffold.mjs \
     --project-dir <project> \
     --web-root <built-web-directory> \
     --app-name <display-name> \
     --app-id <reverse-dns-id> \
     --executable-name <steam-launch-name>
   ```

   The scaffold writes a small Electron main process and `electron-builder.steam.json`. It merges npm scripts and dev dependencies without replacing unrelated package metadata. Review the diff before installing dependencies.

3. Build on a native runner:

   ```text
   node <skill>/scripts/build.mjs --project-dir <project> --platform win --arch x64
   node <skill>/scripts/build.mjs --project-dir <project> --platform mac --arch universal
   ```

   Build Windows on Windows and macOS on macOS. The script runs the configured web build, invokes electron-builder with `--dir`, verifies the output, and can write a JSON result file for later CI steps.

4. Verify before packaging or uploading:

   ```text
   node <skill>/scripts/verify-artifact.mjs \
     --platform win \
     --input <win-unpacked> \
     --expected-executable <Game.exe>

   node <skill>/scripts/verify-artifact.mjs \
     --platform mac \
     --input <Game.app>
   ```

   Treat verification failure as a release-blocking failure. Do not rename an installer to make the check pass.

5. Prepare a CI/handoff archive:

   Windows:

   ```powershell
   & '<skill>\scripts\prepare-steam-win.ps1' `
     -BuildDir '<win-unpacked>' `
     -OutputDir '<artifacts>' `
     -GameKey 'GameName' `
     -Version '1.2.3' `
     -Release Full `
     -EntryExecutable 'Game.exe'
   ```

   macOS:

   ```bash
   node '<skill>/scripts/prepare-steam-mac.mjs' \
     --app '<Game.app>' \
     --output-dir '<artifacts>' \
     --game-key 'GameName' \
     --version '1.2.3' \
     --release full
   ```

6. Upload only after both platform artifacts pass their contracts. Keep Steam credentials and app/depot IDs in the publishing job, not in the build job. Require an explicit full/demo selection and validate that the selected app build includes all required platform depots before making it live.

## Boundaries

- Do not upload or publish a Steam build unless the user explicitly authorizes publishing.
- Do not silently change the Steam launch option. The Windows executable path in Steamworks must exactly match the archive-root entry executable.
- Do not flatten macOS symlinks by default. If an unsigned bundle must pass through a system that destroys links, use `--flatten-symlinks`; the preparation script refuses this for signed apps because it would invalidate the signature.
- Do not package a project root as web content. Point `--web-root` at a dedicated generated frontend directory.
- Do not claim macOS validation from a Windows-only run. Static script tests are not a substitute for a native `.app` build.

