#!/bin/bash

set -e

REPO_URL="https://github.com/dev-ir/Linux-Network-Fixer"
INSTALL_DIR="/opt/linux-network-fixer"
BIN_NAME="linux-net"
BIN_PATH="/usr/local/bin/$BIN_NAME"
CONFIG_PATH="/etc/linux-network-fixer"

echo "🔧 Installing Linux Network Fixer from GitHub..."

# Clone or update repo
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "🔄 Updating existing repo at $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull --quiet
else
  echo "📥 Cloning repo to $INSTALL_DIR..."
  sudo git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

# Make main script executable
sudo chmod +x "$INSTALL_DIR/main.sh"

# Create symlink
echo "🔗 Creating symlink: $BIN_PATH"
sudo ln -sf "$INSTALL_DIR/main.sh" "$BIN_PATH"

# Create config directory if needed
echo "📁 Copying config files to $CONFIG_PATH"
sudo mkdir -p "$CONFIG_PATH"
for file in dns_list.dns ubuntu_sources.mirror test_domains.list; do
  if [ -f "$INSTALL_DIR/$file" ]; then
    sudo cp -n "$INSTALL_DIR/$file" "$CONFIG_PATH/"
  fi
done

echo ""
echo "✅ Done."
echo "You can now run the tool using:"
echo -e "   \033[0;32mlinux-net\033[0m"
