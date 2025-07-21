#!/bin/bash

# Linux Network Fixer Installer

INSTALL_DIR="/opt/linux-network-fixer"
BIN_PATH="/usr/local/bin/linux-net"
CONFIG_DIR="/etc/linux-network-fixer"

set -e

echo -e "\033[1;36m🔧 Installing Linux Network Fixer from GitHub...\033[0m"

# Remove old version if exists
if [ -d "$INSTALL_DIR" ]; then
  echo -e "\033[1;33m⚠️  Old installation detected. Removing...\033[0m"
  sudo rm -rf "$INSTALL_DIR"
fi
if [ -f "$BIN_PATH" ]; then
  sudo rm -f "$BIN_PATH"
fi
if [ -d "$CONFIG_DIR" ]; then
  sudo rm -rf "$CONFIG_DIR"
fi

# Clone fresh
sudo git clone --depth=1 https://github.com/dev-ir/Linux-Network-Fixer.git "$INSTALL_DIR"

# Install binary
sudo install -m 755 "$INSTALL_DIR/main.sh" "$BIN_PATH"

# Copy config files from cloned repo
if [ -d "$INSTALL_DIR" ]; then
  sudo mkdir -p "$CONFIG_DIR"
  sudo cp -r "$INSTALL_DIR/"* "$CONFIG_DIR/"
else
  echo -e "\033[1;31m❌ Config directory not found in cloned repo!\033[0m"
  exit 1
fi

# Add restore-defaults option to binary if not present
if ! grep -q restore_defaults "$INSTALL_DIR/main.sh"; then
  echo -e "\033[1;33m⚠️  Note: 'Restore Defaults' option not detected in main.sh. Consider updating.\033[0m"
fi

echo -e "\033[1;32m✅ Installation complete. Run using: linux-net\033[0m"
