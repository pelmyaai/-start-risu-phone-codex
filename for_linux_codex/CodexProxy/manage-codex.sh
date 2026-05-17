#!/usr/bin/env bash
set -euo pipefail

PROXY_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAWGATE_PORT="${CLAWGATE_PORT:-8082}"
CLAWGATE_HOST="${CLAWGATE_HOST:-127.0.0.1}"
PROXY_PORT="${RISU_CODEX_PORT:-6969}"
PROXY_HOST="${RISU_CODEX_HOST:-127.0.0.1}"

CLAWGATE_PID_FILE="$PROXY_DIR/clawgate.pid"
PROXY_PID_FILE="$PROXY_DIR/proxy.pid"
TUNNEL_PID_FILE="$PROXY_DIR/cloudflared.pid"
TUNNEL_LOG_FILE="$PROXY_DIR/cloudflared.log"
TUNNEL_ERR_FILE="$PROXY_DIR/cloudflared.err.log"
PROXY_LOG_FILE="$PROXY_DIR/proxy.log"
CLAWGATE_LOG_FILE="$PROXY_DIR/clawgate.log"
CONNECTION_INFO_FILE="$PROXY_DIR/connection-info.txt"

stop_pid_file() {
  local pid_file="$1"
  if [ -f "$pid_file" ]; then
    local pid
    pid="$(tr -d '[:space:]' < "$pid_file")"
    if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$pid_file"
  fi
}

cleanup() {
  stop_pid_file "$TUNNEL_PID_FILE"
  stop_pid_file "$PROXY_PID_FILE"
  stop_pid_file "$CLAWGATE_PID_FILE"
}

random_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr '+/' '-_' | tr -d '='
  else
    node -e "console.log(require('crypto').randomBytes(24).toString('base64url'))"
  fi
}

wait_http() {
  local url="$1"
  local name="$2"
  for _ in $(seq 1 45); do
    if node -e "fetch(process.argv[1]).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for $name at $url" >&2
  return 1
}

start_clawgate() {
  stop_pid_file "$CLAWGATE_PID_FILE"
  rm -f "$CLAWGATE_LOG_FILE"
  (
    clawgate --host="$CLAWGATE_HOST" --port="$CLAWGATE_PORT"
  ) > "$CLAWGATE_LOG_FILE" 2>&1 &
  echo $! > "$CLAWGATE_PID_FILE"
  wait_http "http://$CLAWGATE_HOST:$CLAWGATE_PORT" "clawgate"
}

start_proxy() {
  local public_url="$1"
  stop_pid_file "$PROXY_PID_FILE"
  (
    cd "$PROXY_DIR"
    RISU_CODEX_HOST="$PROXY_HOST" \
    RISU_CODEX_PORT="$PROXY_PORT" \
    RISU_CODEX_API_PASSWORD="$RISU_CODEX_API_PASSWORD" \
    RISU_CODEX_UPSTREAM="http://$CLAWGATE_HOST:$CLAWGATE_PORT" \
    RISU_CODEX_PUBLIC_BASE_URL="$public_url" \
    node server.js
  ) > "$PROXY_LOG_FILE" 2>&1 &
  echo $! > "$PROXY_PID_FILE"
  wait_http "http://$PROXY_HOST:$PROXY_PORT/health" "password proxy"
}

start_tunnel() {
  rm -f "$TUNNEL_LOG_FILE" "$TUNNEL_ERR_FILE"
  cloudflared tunnel \
    --url "http://$PROXY_HOST:$PROXY_PORT" \
    --protocol http2 \
    --no-autoupdate \
    --loglevel info \
    --logfile "$TUNNEL_LOG_FILE" \
    > /dev/null \
    2> "$TUNNEL_ERR_FILE" &
  echo $! > "$TUNNEL_PID_FILE"

  for _ in $(seq 1 70); do
    sleep 1
    if [ -f "$TUNNEL_LOG_FILE" ]; then
      local url
      url="$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com' "$TUNNEL_LOG_FILE" | tail -n 1 || true)"
      if [ -n "$url" ]; then
        echo "$url"
        return 0
      fi
    fi
  done

  echo "Timed out waiting for trycloudflare URL. Last cloudflared logs:" >&2
  tail -n 80 "$TUNNEL_LOG_FILE" "$TUNNEL_ERR_FILE" 2>/dev/null || true
  return 1
}

trap cleanup EXIT INT TERM

cleanup
rm -f "$CONNECTION_INFO_FILE"

if [ -z "${RISU_CODEX_API_PASSWORD:-}" ]; then
  export RISU_CODEX_API_PASSWORD="$(random_secret)"
fi

start_clawgate
start_proxy "http://$PROXY_HOST:$PROXY_PORT"
PUBLIC_URL="$(start_tunnel)"
start_proxy "$PUBLIC_URL"

cat > "$CONNECTION_INFO_FILE" <<INFO
base_url=$PUBLIC_URL
health_url=$PUBLIC_URL/health
api_password=$RISU_CODEX_API_PASSWORD
format=Anthropic Claude
model=claude-3-opus
tunnel_enabled=true
INFO

echo
echo "Risu Codex proxy is running."
echo "Base URL:     $PUBLIC_URL"
echo "Health URL:   $PUBLIC_URL/health"
echo "API password: $RISU_CODEX_API_PASSWORD"
echo
echo "Connection info saved to: $CONNECTION_INFO_FILE"
echo "Press Ctrl+C to stop."
echo

tail -f "$PROXY_LOG_FILE" &
TAIL_PID=$!
wait "$(cat "$PROXY_PID_FILE")"
kill "$TAIL_PID" >/dev/null 2>&1 || true
