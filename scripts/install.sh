#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

[ "$EUID" -eq 0 ] && { echo "Error: Do not run as root"; exit 1; }
command -v sudo > /dev/null || { echo "Error: sudo required"; exit 1; }

source "$SCRIPT_DIR/common.sh" || { echo "Error: Failed to load common library"; exit 1; }
init_common

echo "Solana Validator Node - Installation"
echo ""

SOLANA_VERSION="${SOLANA_VERSION:-stable}"

echo "[1/6] Updating packages..."
update_package_lists

echo "[2/6] Installing dependencies..."
CORE_PACKAGES=("build-essential" "pkg-config" "libudev-dev" "libssl-dev" "curl" "git" "wget" "jq" "tmux" "ca-certificates")
get_package_name() {
    case "$OS_FAMILY" in
        debian) case "$1" in build-essential) echo "build-essential" ;; pkg-config) echo "pkg-config" ;; libudev-dev) echo "libudev-dev" ;; libssl-dev) echo "libssl-dev" ;; *) echo "$1" ;; esac ;;
        rhel) case "$1" in build-essential) echo "gcc gcc-c++ make" ;; pkg-config) echo "pkgconfig" ;; libudev-dev) echo "systemd-devel" ;; libssl-dev) echo "openssl-devel" ;; ufw) echo "firewalld" ;; *) echo "$1" ;; esac ;;
        arch) case "$1" in build-essential) echo "base-devel" ;; pkg-config) echo "pkgconf" ;; libudev-dev) echo "systemd" ;; libssl-dev) echo "openssl" ;; *) echo "$1" ;; esac ;;
        *) echo "$1" ;;
    esac
}

MISSING=()
for pkg in "${CORE_PACKAGES[@]}"; do
    distro_pkg=$(get_package_name "$pkg")
    for dp in $distro_pkg; do
        is_package_installed "$dp" || MISSING+=("$dp")
    done
done

[ ${#MISSING[@]} -gt 0 ] && install_packages "${MISSING[@]}" || echo "✓ All dependencies installed"

echo "[3/6] Installing Rust..."
if command_exists rustc; then
    echo "✓ Rust already installed: $(rustc --version 2>/dev/null | head -1)"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || { echo "✗ Rust installation failed"; exit 1; }
    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
    add_to_path "$HOME/.cargo/bin"
    echo "✓ Rust installed"
fi

echo "[4/6] Installing Solana CLI ($SOLANA_VERSION)..."
if [ "$SOLANA_VERSION" = "stable" ]; then
    INSTALL_URLS=("https://release.anza.xyz/stable/install" "https://release.solana.com/stable/install")
elif [ "$SOLANA_VERSION" = "beta" ]; then
    INSTALL_URLS=("https://release.anza.xyz/beta/install" "https://release.solana.com/beta/install")
else
    INSTALL_URLS=("https://release.anza.xyz/$SOLANA_VERSION/install" "https://release.solana.com/$SOLANA_VERSION/install")
fi

INSTALL_SUCCESS=false
for URL in "${INSTALL_URLS[@]}"; do
    sh -c "$(curl -sSfL "$URL")" 2>/dev/null && INSTALL_SUCCESS=true && break
done

if [ "$INSTALL_SUCCESS" = false ]; then
    INSTALL_SCRIPT="/tmp/solana-install.sh"
    for URL in "${INSTALL_URLS[@]}"; do
        curl -sSfL "$URL" -o "$INSTALL_SCRIPT" 2>/dev/null || curl -k -sSfL "$URL" -o "$INSTALL_SCRIPT" 2>/dev/null
        [ -f "$INSTALL_SCRIPT" ] && chmod +x "$INSTALL_SCRIPT" && sh "$INSTALL_SCRIPT" && INSTALL_SUCCESS=true && rm -f "$INSTALL_SCRIPT" && break
    done
fi

[ "$INSTALL_SUCCESS" = false ] && { echo "✗ Solana installation failed"; exit 1; }

add_to_path "$HOME/.local/share/solana/install/active_release/bin"
command_exists solana || { echo "✗ Solana CLI not found after installation"; exit 1; }
echo "✓ Solana installed: $(solana --version 2>/dev/null | head -1)"

echo "[5/6] Installing Anchor..."
if command_exists anchor; then
    echo "✓ Anchor already installed"
else
    command_exists cargo || { echo "⚠ Cargo not found, skipping Anchor"; }
    cargo install --git https://github.com/coral-xyz/anchor avm --locked --force > /dev/null 2>&1 && \
        command_exists avm && avm install latest > /dev/null 2>&1 && avm use latest > /dev/null 2>&1 && \
        echo "✓ Anchor installed" || echo "⚠ Anchor installation failed (non-critical)"
fi

echo "[6/6] Configuring shell profile..."
SHELL_PROFILE=""
[ -f "$HOME/.bashrc" ] && SHELL_PROFILE="$HOME/.bashrc"
[ -f "$HOME/.bash_profile" ] && [ -z "$SHELL_PROFILE" ] && SHELL_PROFILE="$HOME/.bash_profile"
[ -f "$HOME/.zshrc" ] && [ -z "$SHELL_PROFILE" ] && SHELL_PROFILE="$HOME/.zshrc"

if [ -n "$SHELL_PROFILE" ]; then
    grep -q "export PATH.*solana" "$SHELL_PROFILE" 2>/dev/null || echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> "$SHELL_PROFILE"
    grep -q "export PATH.*cargo" "$SHELL_PROFILE" 2>/dev/null || echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$SHELL_PROFILE"
    echo "✓ Shell profile configured: $SHELL_PROFILE"
fi

mkdir -p "${PROGRAMS_DIR:-$HOME/.local/share/solana-programs}"

echo ""
echo "Installation Complete!"
echo "  Rust: $(rustc --version 2>/dev/null | head -1 || echo 'Not in PATH')"
echo "  Solana: $(solana --version 2>/dev/null | head -1 || echo 'Not in PATH')"
echo "  Anchor: $(anchor --version 2>/dev/null | head -1 || echo 'Not installed')"
echo ""
echo "Next: source $SHELL_PROFILE && ./scripts/setup-cluster.sh"
