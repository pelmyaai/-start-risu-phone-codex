#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -f "./env.sh" ]; then
  # shellcheck disable=SC1091
  source ./env.sh
fi

if ! command -v clawgate >/dev/null 2>&1; then
  echo "clawgate is not installed."
  echo "Run: bash setup_user.sh && source ./env.sh"
  exit 1
fi

echo "Checking clawgate login status..."
if clawgate status >/dev/null 2>&1; then
  clawgate status
  echo
  echo "Already logged in. You can run: bash start_detached.sh"
  exit 0
fi

echo "Starting ChatGPT/Codex login."
echo "Open the URL shown below, sign in, then return here."
clawgate login
