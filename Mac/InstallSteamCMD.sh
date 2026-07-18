#!/bin/bash

# Install the macOS SteamCMD distribution used by SteamPackFlow.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
INSTALL_DIR="$SCRIPT_DIR/builder"
STEAMCMD_URL="${STEAMCMD_URL:-https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz}"

usage() {
    cat <<'EOF'
Usage: InstallSteamCMD.sh [options]

Options:
  --install-dir DIR  Extract SteamCMD into DIR (default: Mac/builder).
  --url URL          Override the SteamCMD archive URL.
  -h, --help         Show this help.
EOF
}

error() { printf '[ERROR] %s\n' "$1" >&2; }
info() { printf '[INFO] %s\n' "$1"; }

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install-dir)
                [[ $# -ge 2 ]] || { error 'Missing value for --install-dir.'; return 1; }
                INSTALL_DIR="$2"; shift 2 ;;
            --url)
                [[ $# -ge 2 ]] || { error 'Missing value for --url.'; return 1; }
                STEAMCMD_URL="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) error "Unknown option: $1"; return 1 ;;
        esac
    done
}

main() {
    parse_args "$@" || return 1
    command -v curl >/dev/null 2>&1 || { error 'curl is required.'; return 1; }
    command -v tar >/dev/null 2>&1 || { error 'tar is required.'; return 1; }
    mkdir -p "$INSTALL_DIR" || { error "Could not create $INSTALL_DIR"; return 1; }

    local target archive extract_dir found source_root
    target="$INSTALL_DIR/steamcmd.sh"
    if [[ -f "$target" && ! -x "$target" ]]; then
        chmod +x "$target" 2>/dev/null || true
    fi
    if [[ -f "$target" && -x "$target" ]]; then
        info "SteamCMD is already installed: $target"
        return 0
    fi

    archive="$(mktemp "${TMPDIR:-/tmp}/steampackflow-steamcmd.XXXXXX")" || return 1
    extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/steampackflow-steamcmd.XXXXXX")" || { rm -f "$archive"; return 1; }
    trap '[[ -n "${archive:-}" ]] && rm -f "$archive"; [[ -n "${extract_dir:-}" ]] && rm -rf "$extract_dir"' EXIT HUP INT TERM

    info "Downloading SteamCMD from $STEAMCMD_URL"
    if ! curl --fail --location --show-error --silent --retry 3 --retry-delay 2 --output "$archive" "$STEAMCMD_URL"; then
        error "Could not download SteamCMD from $STEAMCMD_URL"
        return 1
    fi
    if ! tar -xzf "$archive" -C "$extract_dir"; then
        error 'Could not extract the SteamCMD archive.'
        return 1
    fi

    found=''
    if [[ -f "$extract_dir/steamcmd.sh" ]]; then
        found="$extract_dir/steamcmd.sh"
    else
        found="$(find "$extract_dir" -type f -name steamcmd.sh -print -quit)"
    fi
    if [[ -z "$found" ]]; then
        error 'The downloaded archive did not contain steamcmd.sh.'
        return 1
    fi
    source_root="$(dirname "$found")"
    if ! cp -R "$source_root"/. "$INSTALL_DIR"/; then
        error "Could not install SteamCMD into $INSTALL_DIR"
        return 1
    fi
    chmod +x "$target" 2>/dev/null || true
    if [[ ! -f "$target" || ! -x "$target" ]]; then
        error "SteamCMD was extracted, but is not executable at $target"
        return 1
    fi

    info "SteamCMD installed: $target"
    if [[ "$(uname -m 2>/dev/null || true)" == 'arm64' ]] && command -v arch >/dev/null 2>&1; then
        if ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
            printf '[WARN] Apple Silicon may need Rosetta 2: softwareupdate --install-rosetta --agree-to-license\n' >&2
        fi
    fi
    return 0
}

main "$@"
exit_code=$?
exit "$exit_code"
