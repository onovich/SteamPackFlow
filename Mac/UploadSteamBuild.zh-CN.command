#!/bin/bash
cd "$(dirname "$0")" || exit 1
./UploadSteamBuild.sh --language zh-CN "$@"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    printf '\n上传器退出码：%s。按 Enter 关闭窗口。\n' "$exit_code"
    read -r _ || true
fi
exit "$exit_code"
