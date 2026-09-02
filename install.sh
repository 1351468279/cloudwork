#!/usr/bin/env bash
# CloudWork macOS & Linux One-Line Installer
set -e

echo -e "\033[36m==========================================================\033[0m"
echo -e "\033[32m   ⚡ Installing CloudWork AI Agent Commander (macOS/Linux)\033[0m"
echo -e "\033[36m==========================================================\033[0m"

INSTALL_DIR="$HOME/.cloudwork/bin"
mkdir -p "$INSTALL_DIR"
BINARY_PATH="$INSTALL_DIR/cloudwork"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
fi

echo "Detected OS: $OS, Architecture: $ARCH"

# If local build exists, use it
if [ -f "./daemon/bin/cloudwork-daemon" ]; then
    cp "./daemon/bin/cloudwork-daemon" "$BINARY_PATH"
    chmod +x "$BINARY_PATH"
    echo -e "\033[32m✓ Installed local build to $BINARY_PATH\033[0m"
else
    DOWNLOAD_URL="https://github.com/cloudwork/cloudwork/releases/latest/download/cloudwork-daemon-${OS}-${ARCH}"
    echo "Downloading binary from $DOWNLOAD_URL..."
    curl -fsSL "$DOWNLOAD_URL" -o "$BINARY_PATH" || {
        echo -e "\033[31m⚠️ Download failed. Please build locally with: cd daemon && go build -o bin/cloudwork ./cmd/cloudwork-daemon\033[0m"
        exit 1
    }
    chmod +x "$BINARY_PATH"
    echo -e "\033[32m✓ Download complete and permissions set!\033[0m"
fi

# Add to PATH if not present
SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

if ! grep -q "$INSTALL_DIR" "$SHELL_RC" 2>/dev/null; then
    echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
    echo -e "\033[32m✓ Added $INSTALL_DIR to $SHELL_RC\033[0m"
fi

echo -e "\n\033[32m🎉 Installation Succeeded!\033[0m"
echo -e "\033[36mRestart your terminal or run 'source $SHELL_RC', then type 'cloudwork' to start!\033[0m"
