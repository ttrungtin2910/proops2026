#!/usr/bin/env bash
# KHÔNG có set -e

mkdir /protected-dir
cd /protected-dir
echo "Tôi đang ở: $(pwd)"
echo "Script kết thúc với exit code: $?"

fake-command
echo "Exit code: $?"     # → 127 (command not found)