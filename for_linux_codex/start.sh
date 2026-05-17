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

bash CodexProxy/manage-codex.sh "$@"
