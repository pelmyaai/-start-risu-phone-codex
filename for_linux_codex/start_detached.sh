#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -f "./env.sh" ]; then
  # shellcheck disable=SC1091
  source ./env.sh
fi

if ! command -v clawgate >/dev/null 2>&1; then
  echo "clawgate is not installed. Run: bash setup_user.sh && source ./env.sh"
  exit 1
fi

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared is not installed. Run: bash setup_user.sh && source ./env.sh"
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node is not installed. Run: bash setup_user.sh && source ./env.sh"
  exit 1
fi

if ! clawgate status >/dev/null 2>&1; then
  echo "clawgate is not logged in. Run: bash login.sh"
  exit 1
fi

read -r -s -p "Risu API password: " RISU_CODEX_API_PASSWORD
echo

if [ -z "$RISU_CODEX_API_PASSWORD" ]; then
  echo "Password cannot be empty."
  exit 1
fi

export RISU_CODEX_API_PASSWORD
export NODE_ENV=production

rm -f CodexProxy/connection-info.txt CodexProxy/launcher.log

nohup bash CodexProxy/manage-codex.sh "$@" > CodexProxy/launcher.log 2>&1 &
launcher_pid=$!
echo "$launcher_pid" > CodexProxy/launcher.pid

echo "Starting detached Risu Codex proxy..."

for _ in $(seq 1 90); do
  if [ -f "CodexProxy/connection-info.txt" ]; then
    echo
    echo "Risu Codex proxy is running in the background."
    echo "Launcher PID: $launcher_pid"
    echo
    cat CodexProxy/connection-info.txt
    echo
    echo "Use these in RisuAI:"
    echo "  URL:          $(grep '^base_url=' CodexProxy/connection-info.txt | cut -d= -f2-)"
    echo "  API password: the password you just entered"
    echo "  Format:       Anthropic Claude"
    echo "  Model:        claude-3-opus"
    echo
    echo "Logs:"
    echo "  CodexProxy/launcher.log"
    echo "  CodexProxy/proxy.log"
    echo "  CodexProxy/clawgate.log"
    echo
    echo "You can close this SSH window now."
    echo "To stop later: bash stop.sh"
    exit 0
  fi

  if ! kill -0 "$launcher_pid" >/dev/null 2>&1; then
    echo "Detached launcher exited before startup completed."
    echo "Last launcher log lines:"
    tail -n 120 CodexProxy/launcher.log 2>/dev/null || true
    exit 1
  fi

  sleep 1
done

echo "Timed out waiting for connection-info.txt."
echo "The process may still be starting. Check:"
echo "  tail -n 120 CodexProxy/launcher.log"
exit 1
