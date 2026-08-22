# Steam artifact contract

These checks are release gates, not suggestions.

## Windows

Input to the archive step must be a directory produced by an unpacked electron-builder build (`--dir`).

Required:

- The exact Steam launch executable exists at directory root, including case and `.exe`.
- `resources/app.asar` exists, or `resources/app` is a directory.
- Electron runtime/support files remain beside the executable.
- The handoff ZIP contains directory contents at ZIP root, so the executable is `<Game.exe>`, not `win-unpacked/<Game.exe>`.

Rejected:

- A single `.exe` file.
- An NSIS/MSI/setup executable, even if renamed to the expected launch name.
- Any `.blockmap` file.
- An archive containing only an executable and `.blockmap`.
- An archive with an unexpected wrapper directory.

Steamworks launch options must name the same root executable. Renaming is allowed only while assembling a verified unpacked directory, never as a substitute for packaging the correct target.

## macOS

Input to the archive step must be one `.app` directory produced on macOS.

Required:

- `Contents/Info.plist`.
- At least one executable in `Contents/MacOS`.
- `Contents/Frameworks/Electron Framework.framework`.
- Framework links and Unix executable modes are preserved in transit.
- The handoff ZIP has `<Game.app>/...` at ZIP root.

Rejected:

- `.dmg`, `.pkg`, or a ZIP in place of the source `.app` during verification.
- A partial `.app` copied without frameworks.
- Flattening a signed bundle. It changes signed content and invalidates the signature.

When an unsigned `.app` must cross a Windows-oriented storage/upload path that cannot preserve links, `prepare-steam-mac.mjs --flatten-symlinks` creates a disposable flattened copy before archiving. Prefer a native macOS build-to-upload route that preserves the original bundle.

## Cross-platform release gate

Before Steam upload, record and compare:

| Field | Required value |
| --- | --- |
| Version | One exact version for web build, Electron package, archive, and Steam build description |
| Release | Explicit `full` or `demo` |
| Windows entry | Exact root `.exe` matching the Steam launch option |
| macOS entry | Exact `.app` and its `Contents/MacOS` executable |
| Platforms | Every depot expected by the selected Steam app/build |
| Hash | SHA-256 of each handoff archive |

Do not promote a build live when the selected app expects both operating systems but only one depot was staged.

