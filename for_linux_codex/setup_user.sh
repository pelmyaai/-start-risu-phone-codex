#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

INSTALL_DIR="$HOME/.local/risu-codex-runtime"
BIN_DIR="$HOME/.local/bin"
NODE_VERSION="${NODE_VERSION:-v22.16.0}"

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64)
    node_arch="x64"
    cloudflared_arch="amd64"
    clawgate_arch="amd64"
    ;;
  aarch64|arm64)
    node_arch="arm64"
    cloudflared_arch="arm64"
    clawgate_arch="arm64"
    ;;
  *)
    echo "Unsupported architecture: $arch"
    exit 1
    ;;
esac

download() {
  local url="$1"
  local output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$output" "$url"
  else
    echo "curl or wget is required."
    exit 1
  fi
}

node_dir="$INSTALL_DIR/node-$NODE_VERSION-linux-$node_arch"
if [ ! -x "$node_dir/bin/node" ]; then
  tmp_tar="$(mktemp --suffix=.tar.xz)"
  echo "Downloading Node.js $NODE_VERSION..."
  download "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-$node_arch.tar.xz" "$tmp_tar"
  rm -rf "$node_dir"
  tar -xJf "$tmp_tar" -C "$INSTALL_DIR"
  rm -f "$tmp_tar"
fi

cloudflared_path="$BIN_DIR/cloudflared"
if [ ! -x "$cloudflared_path" ]; then
  echo "Downloading cloudflared..."
  download "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cloudflared_arch" "$cloudflared_path"
  chmod +x "$cloudflared_path"
fi

clawgate_path="$BIN_DIR/clawgate"
if [ ! -x "$clawgate_path" ]; then
  echo "Installing clawgate..."
  tmp_install="$(mktemp)"
  download "https://clawgate.org/install.sh" "$tmp_install"
  bash "$tmp_install"
  rm -f "$tmp_install"
fi

if [ ! -x "$clawgate_path" ] && [ -x "$HOME/.clawgate/bin/clawgate" ]; then
  ln -sf "$HOME/.clawgate/bin/clawgate" "$clawgate_path"
fi

if [ ! -x "$clawgate_path" ] && command -v clawgate >/dev/null 2>&1; then
  clawgate_found="$(command -v clawgate)"
  ln -sf "$clawgate_found" "$clawgate_path"
fi

if [ ! -x "$clawgate_path" ]; then
  echo "clawgate install did not create $clawgate_path."
  echo "Try manually: curl -fsSL https://clawgate.org/install.sh | bash"
  exit 1
fi

cat > env.sh <<ENV
export PATH="$node_dir/bin:$BIN_DIR:\$HOME/.clawgate/bin:\$PATH"
ENV

chmod +x login.sh start.sh start_detached.sh stop.sh CodexProxy/manage-codex.sh

echo
echo "Setup complete."
echo "Run:"
echo "  source ./env.sh"
echo "  bash login.sh"
echo "  bash start_detached.sh"
