#!/bin/bash
cd "$(dirname "$0")" || exit 1
./InstallSteamCMD.sh "$@"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    printf '\nSteamCMD installer exited with code %s. Press Enter to close.\nSteamCMD 安装器退出码：%s。按 Enter 关闭窗口。\n' "$exit_code" "$exit_code"
    read -r _ || true
fi
exit "$exit_code"
