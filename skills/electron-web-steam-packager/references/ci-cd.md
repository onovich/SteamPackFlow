# CI/CD integration

## Pipeline shape

Use separate build and publish boundaries:

```text
web build
  -> native Windows/macOS Electron build
  -> artifact verification
  -> transport archive + SHA-256
  -> CI artifact retention
  -> explicit Steam release selection
  -> SteamPipe staging upload
  -> cross-depot check
  -> optional live-branch promotion
```

The build jobs do not need Steam credentials. Keep credentials, app IDs, depot IDs, branch names, and live-promotion permission in a protected publishing environment.

## Native matrix

- Build Windows on a Windows runner.
- Build macOS on a macOS runner.
- Keep the target architecture explicit (`x64`, `arm64`, or `universal`).
- Archive the `.app` on macOS before uploading it as a CI artifact. Generic artifact stores may not retain symlinks or Unix modes when given a directory directly.

## Inputs that must be explicit

- Release version.
- `full` or `demo`.
- Windows launch executable.
- Product/bundle name.
- Required platform depots.
- Whether macOS is signed/notarized.

Do not route full versus demo only by searching for `_Demo` after the build. The release kind should be a validated pipeline input and should also be written into the artifact manifest/archive name for human review.

## Failure policy

Fail before upload when:

- The web build did not create the configured web root or HTML entry.
- electron-builder produced an installer target instead of an unpacked target.
- The entry executable or `.app` contract fails.
- The package version differs from the release version.
- Full/demo is absent or ambiguous.
- A required platform job is missing.
- A Steam app build VDF does not include every required depot.

## Template use

Copy `assets/github-actions/electron-steam-build.yml` to `.github/workflows/`. Edit the values marked `ADAPT`, copy this skill directory into `tools/`, and pin third-party actions to reviewed commit SHAs in production.

The template intentionally stops after verified archives. Add SteamPipe upload as a separate protected job or workflow after the project has supplied its own app/depot mapping and promotion policy.

