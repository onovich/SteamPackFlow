#!/bin/bash
cd "$(dirname "$0")" || exit 1
./UploadSteamBuild.sh --language en-US "$@"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    printf '\nUploader exited with code %s. Press Enter to close this window.\n' "$exit_code"
    read -r _ || true
fi
exit "$exit_code"
