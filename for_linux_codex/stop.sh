#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/CodexProxy"

for pid_file in cloudflared.pid proxy.pid clawgate.pid launcher.pid; do
  if [ -f "$pid_file" ]; then
    pid="$(tr -d '[:space:]' < "$pid_file")"
    if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$pid_file"
  fi
done

echo "Stopped Risu Codex proxy processes."
