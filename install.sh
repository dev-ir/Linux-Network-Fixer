#!/bin/bash

set -e

echo "🔧 Installing Linux Network Fixer from GitHub..."

INSTALL_DIR="/opt/linux-network-fixer"
BIN_PATH="/usr/local/bin/linux-net"
CONFIG_DIR="/etc/linux-network-fixer"

# Remove if exists
if [[ -d "$INSTALL_DIR" ]]; then
  echo "🧹 Removing previous installation..."
  sudo rm -rf "$INSTALL_DIR"
fi

if [[ -f "$BIN_PATH" ]]; then
  sudo rm -f "$BIN_PATH"
fi

if [[ -d "$CONFIG_DIR" ]]; then
  sudo rm -rf "$CONFIG_DIR"
fi

# Clone the latest version
echo "📥 Cloning repository..."
sudo git clone --depth=1 https://github.com/dev-ir/Linux-Network-Fixer.git "$INSTALL_DIR"

# Copy main script
sudo cp "$INSTALL_DIR/main.sh" "$BIN_PATH"
sudo chmod +x "$BIN_PATH"

# Copy config directory
sudo mkdir -p "$CONFIG_DIR"
sudo cp -r "$INSTALL_DIR/config/." "$CONFIG_DIR/"

echo "✅ Installed successfully. Run with: linux-net"
