#!/bin/bash

set -e

echo "🔧 Installing Linux Network Fixer from GitHub..."

INSTALL_DIR="/opt/linux-network-fixer"
BIN_PATH="/usr/local/bin/linux-net"
CONFIG_DIR="/etc/linux-network-fixer"

# Remove any previous versions
echo "🧹 Cleaning previous versions..."
sudo rm -rf "$INSTALL_DIR"
sudo rm -f "$BIN_PATH"
sudo rm -rf "$CONFIG_DIR"

# Clone latest version
echo "📥 Cloning repository..."
sudo git clone --depth=1 https://github.com/dev-ir/Linux-Network-Fixer.git "$INSTALL_DIR"

# Install main script
echo "📦 Installing main executable..."
sudo install -m 755 "$INSTALL_DIR/main.sh" "$BIN_PATH"

# Copy config files
echo "⚙️ Setting up configuration..."
sudo mkdir -p "$CONFIG_DIR"
sudo cp -r "$INSTALL_DIR/config/." "$CONFIG_DIR/"

echo "✅ Linux Network Fixer installed successfully!"
echo "👉 Run with: linux-net"
