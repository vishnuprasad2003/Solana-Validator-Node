#!/usr/bin/env bash
#
# Solana Validator Node - Installation Script
# Installs Rust, Solana CLI, and all required dependencies
# This script is idempotent - safe to run multiple times
# Portable across Linux distributions (Debian, RHEL, Arch, etc.)
#

set -euo pipefail

# Script directory (handles spaces in path)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load common library
# shellcheck source=common.sh
if ! source "$SCRIPT_DIR/common.sh"; then
    echo "Error: Failed to load common library" >&2
    exit 1
fi

# Initialize common library
init_common

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Load configuration
if ! safe_source "$REPO_ROOT/configs/config.env"; then
    echo -e "${RED}Error: config.env not found at $REPO_ROOT/configs/config.env${NC}" >&2
    exit 1
fi

# Setup logging
safe_mkdir "$REPO_ROOT/logs"
readonly LOG_FILE="$REPO_ROOT/logs/install.log"

# Override logging functions from common.sh
log_info() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$timestamp [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$timestamp [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$timestamp [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$timestamp [ERROR] $1" >> "$LOG_FILE"
}

# Check prerequisites
check_not_root
check_sudo

# Log system information
log_info "Detected system: $OS_FAMILY (Package Manager: $PACKAGE_MANAGER, Architecture: $ARCHITECTURE)"

echo "=========================================="
echo "Solana Validator Node - Installation"
echo "=========================================="
echo ""

# Step 1: Update system packages
log_info "[1/6] Updating system packages..."
update_package_lists
log_success "System packages updated"

# Step 2: Install system dependencies
log_info "[2/6] Installing system dependencies..."

# Map packages to distribution-specific names
get_package_name() {
    local package="$1"
    case "$OS_FAMILY" in
        debian)
            case "$package" in
                build-essential) echo "build-essential" ;;
                pkg-config) echo "pkg-config" ;;
                libudev-dev) echo "libudev-dev" ;;
                libssl-dev) echo "libssl-dev" ;;
                curl) echo "curl" ;;
                git) echo "git" ;;
                wget) echo "wget" ;;
                jq) echo "jq" ;;
                tmux) echo "tmux" ;;
                ufw) echo "ufw" ;;
                ca-certificates) echo "ca-certificates" ;;
                *) echo "$package" ;;
            esac
            ;;
        rhel)
            case "$package" in
                build-essential) echo "gcc gcc-c++ make" ;;
                pkg-config) echo "pkgconfig" ;;
                libudev-dev) echo "systemd-devel" ;;
                libssl-dev) echo "openssl-devel" ;;
                curl) echo "curl" ;;
                git) echo "git" ;;
                wget) echo "wget" ;;
                jq) echo "jq" ;;
                tmux) echo "tmux" ;;
                ufw) echo "firewalld" ;;
                ca-certificates) echo "ca-certificates" ;;
                *) echo "$package" ;;
            esac
            ;;
        arch)
            case "$package" in
                build-essential) echo "base-devel" ;;
                pkg-config) echo "pkgconf" ;;
                libudev-dev) echo "systemd" ;;
                libssl-dev) echo "openssl" ;;
                curl) echo "curl" ;;
                git) echo "git" ;;
                wget) echo "wget" ;;
                jq) echo "jq" ;;
                tmux) echo "tmux" ;;
                ufw) echo "ufw" ;;
                ca-certificates) echo "ca-certificates" ;;
                *) echo "$package" ;;
            esac
            ;;
        *)
            echo "$package"
            ;;
    esac
}

# Core required packages (distribution-agnostic names)
CORE_PACKAGES=(
    "build-essential"
    "pkg-config"
    "libudev-dev"
    "libssl-dev"
    "curl"
    "git"
    "wget"
    "jq"
    "tmux"
    "ca-certificates"
)

# Convert to distribution-specific packages
DISTRO_PACKAGES=()
for pkg in "${CORE_PACKAGES[@]}"; do
    distro_pkg=$(get_package_name "$pkg")
    # Handle multi-package entries (space-separated)
    for dp in $distro_pkg; do
        DISTRO_PACKAGES+=("$dp")
    done
done

# Check and install missing packages
MISSING_PACKAGES=()
for package in "${DISTRO_PACKAGES[@]}"; do
    if ! is_package_installed "$package"; then
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    log_info "Installing missing packages: ${MISSING_PACKAGES[*]}"
    if install_packages "${MISSING_PACKAGES[@]}"; then
        log_success "Dependencies installed"
    else
        log_error "Failed to install some packages"
        exit 1
    fi
else
    log_success "All required dependencies are installed"
fi

# Update CA certificates (helps with SSL issues)
log_info "Updating CA certificates..."
case "$OS_FAMILY" in
    debian)
        sudo update-ca-certificates > /dev/null 2>&1 || true
        ;;
    rhel)
        sudo update-ca-trust > /dev/null 2>&1 || true
        ;;
esac

# Step 3: Install Rust
log_info "[3/6] Checking Rust installation..."
if command_exists rustc; then
    RUST_VERSION=$(rustc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    log_success "Rust is already installed (version $RUST_VERSION)"
else
    log_info "Installing Rust..."
    require_command curl "curl is required to install Rust"
    
    # Install Rust using official installer
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        # Source cargo environment
        if [ -f "$HOME/.cargo/env" ]; then
            # shellcheck source=/dev/null
            source "$HOME/.cargo/env"
        fi
        add_to_path "$HOME/.cargo/bin"
        log_success "Rust installed successfully"
        rustc --version
    else
        log_error "Rust installation failed"
        exit 1
    fi
fi

# Ensure cargo is in PATH
add_to_path "$HOME/.cargo/bin"

# Step 4: Install Solana CLI
log_info "[4/6] Installing Solana CLI ($SOLANA_VERSION version)..."

# Install or update Solana
if command -v solana &> /dev/null; then
    CURRENT_VERSION=$(solana --version 2>/dev/null | head -1 || echo "unknown")
    log_info "Solana CLI is already installed ($CURRENT_VERSION)"
    log_info "Updating to $SOLANA_VERSION version..."
else
    log_info "Installing Solana CLI ($SOLANA_VERSION)..."
fi

# Determine installation URLs (try both official domains)
if [ "$SOLANA_VERSION" = "stable" ]; then
    INSTALL_URLS=(
        "https://release.anza.xyz/stable/install"
        "https://release.solana.com/stable/install"
    )
elif [ "$SOLANA_VERSION" = "beta" ]; then
    INSTALL_URLS=(
        "https://release.anza.xyz/beta/install"
        "https://release.solana.com/beta/install"
    )
else
    INSTALL_URLS=(
        "https://release.anza.xyz/$SOLANA_VERSION/install"
        "https://release.solana.com/$SOLANA_VERSION/install"
    )
fi

INSTALL_SUCCESS=false

# Method 1: Standard official installation (recommended)
log_info "Attempting standard installation method..."
for INSTALL_URL in "${INSTALL_URLS[@]}"; do
    log_info "Trying: $INSTALL_URL"
    if sh -c "$(curl -sSfL "$INSTALL_URL")"; then
        INSTALL_SUCCESS=true
        break
    fi
done

# Method 2: Download script first, then execute (handles SSL issues better)
if [ "$INSTALL_SUCCESS" = false ]; then
    log_info "Trying alternative method: download then execute..."
    INSTALL_SCRIPT="/tmp/solana-install.sh"
    rm -f "$INSTALL_SCRIPT"
    
    for INSTALL_URL in "${INSTALL_URLS[@]}"; do
        log_info "Downloading from: $INSTALL_URL"
        # Try with standard curl
        if curl -sSfL "$INSTALL_URL" -o "$INSTALL_SCRIPT" 2>/dev/null; then
            chmod +x "$INSTALL_SCRIPT"
            if sh "$INSTALL_SCRIPT"; then
                INSTALL_SUCCESS=true
                rm -f "$INSTALL_SCRIPT"
                break
            fi
        fi
        
        # Try with relaxed SSL verification
        if curl -k -sSfL "$INSTALL_URL" -o "$INSTALL_SCRIPT" 2>/dev/null; then
            chmod +x "$INSTALL_SCRIPT"
            if sh "$INSTALL_SCRIPT"; then
                INSTALL_SUCCESS=true
                rm -f "$INSTALL_SCRIPT"
                break
            fi
        fi
        
        # Try with wget if available
        if command -v wget &> /dev/null; then
            if wget --no-check-certificate -q -O "$INSTALL_SCRIPT" "$INSTALL_URL" 2>/dev/null; then
                chmod +x "$INSTALL_SCRIPT"
                if sh "$INSTALL_SCRIPT"; then
                    INSTALL_SUCCESS=true
                    rm -f "$INSTALL_SCRIPT"
                    break
                fi
            fi
        fi
    done
    rm -f "$INSTALL_SCRIPT"
fi

# Method 3: Manual installation from GitHub releases (final fallback)
if [ "$INSTALL_SUCCESS" = false ]; then
    log_warning "Standard installation methods failed. Attempting manual installation from GitHub..."
    
        # Use detected architecture from common library
        ARCH_NAME="$ARCHITECTURE"
        
        if [ "$ARCH_NAME" = "unknown" ]; then
            log_error "Unsupported architecture: $(uname -m)"
            ARCH_NAME=""
        fi
    
    if [ -n "$ARCH_NAME" ]; then
        log_info "Detected architecture: $ARCH_NAME"
        
        # Try to get latest release from GitHub API
        if command -v jq &> /dev/null; then
            LATEST_TAG=$(curl -s https://api.github.com/repos/solana-labs/solana/releases/latest | jq -r '.tag_name' 2>/dev/null | sed 's/^v//')
        fi
        
        if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
            # Fallback: use a known stable version
            LATEST_TAG="1.18.0"
            log_warning "Could not fetch latest version, using fallback: $LATEST_TAG"
        fi
        
        RELEASE_URL="https://github.com/solana-labs/solana/releases/download/v${LATEST_TAG}/solana-release-${ARCH_NAME}.tar.bz2"
        INSTALL_DIR="$HOME/.local/share/solana/install/releases/${LATEST_TAG}"
        
        log_info "Downloading Solana ${LATEST_TAG} from GitHub releases..."
        mkdir -p "$INSTALL_DIR"
        
        if curl -sSfL "$RELEASE_URL" -o "/tmp/solana-release.tar.bz2" 2>/dev/null || \
           curl -k -sSfL "$RELEASE_URL" -o "/tmp/solana-release.tar.bz2" 2>/dev/null; then
            log_info "Extracting Solana release..."
            cd "$INSTALL_DIR"
            if tar -xjf /tmp/solana-release.tar.bz2 2>/dev/null; then
                # Create symlink for active_release
                mkdir -p "$HOME/.local/share/solana/install"
                rm -f "$HOME/.local/share/solana/install/active_release"
                ln -sf "$INSTALL_DIR/solana-release" "$HOME/.local/share/solana/install/active_release"
                INSTALL_SUCCESS=true
                rm -f /tmp/solana-release.tar.bz2
                log_success "Manual installation from GitHub completed"
            else
                rm -f /tmp/solana-release.tar.bz2
            fi
        fi
    fi
fi

if [ "$INSTALL_SUCCESS" = false ]; then
    log_error "Solana CLI installation failed with all methods"
    log_error ""
    log_error "Please try manual installation:"
    log_error "  1. Visit: https://github.com/solana-labs/solana/releases"
    log_error "  2. Download the appropriate release for your system"
    log_error "  3. Extract and add to PATH: export PATH=\"\$HOME/.local/share/solana/install/active_release/bin:\$PATH\""
    exit 1
fi

# Add Solana to PATH
add_to_path "$HOME/.local/share/solana/install/active_release/bin"

# Verify installation
if command_exists solana; then
    INSTALLED_VERSION=$(solana --version 2>/dev/null | head -1 || echo "")
    log_success "Solana CLI installed successfully"
    echo "  Version: $INSTALLED_VERSION"
else
    log_error "Solana CLI installation failed"
    exit 1
fi

# Step 5: Install Anchor (optional, for program development)
log_info "[5/6] Installing Anchor framework..."
if command_exists anchor; then
    log_success "Anchor is already installed"
    anchor --version
else
    log_info "Installing Anchor..."
    require_command cargo "cargo is required to install Anchor"
    
    if cargo install --git https://github.com/coral-xyz/anchor avm --locked --force > /dev/null 2>&1; then
        add_to_path "$HOME/.cargo/bin"
        if command_exists avm; then
            avm install latest > /dev/null 2>&1
            avm use latest > /dev/null 2>&1
            log_success "Anchor installed successfully"
            anchor --version
        else
            log_warning "Anchor AVM installed but avm command not found in PATH"
        fi
    else
        log_warning "Anchor installation failed (non-critical)"
    fi
fi

# Step 6: Configure shell profile
log_info "[6/6] Configuring shell profile..."

# Detect shell profile dynamically
detect_shell_profile() {
    local shell_name
    shell_name=$(detect_shell)
    
    case "$shell_name" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            fi
            ;;
        zsh)
            if [ -f "$HOME/.zshrc" ]; then
                echo "$HOME/.zshrc"
            fi
            ;;
        fish)
            if [ -d "$HOME/.config/fish" ]; then
                echo "$HOME/.config/fish/config.fish"
            fi
            ;;
    esac
}

SHELL_PROFILE=$(detect_shell_profile)

if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
    # Add Solana to PATH if not already present
    if ! grep -q "export PATH.*solana" "$SHELL_PROFILE" 2>/dev/null; then
        {
            echo ""
            echo "# Solana CLI PATH"
            echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
        } >> "$SHELL_PROFILE"
        log_success "Added Solana to $SHELL_PROFILE"
    else
        log_success "Solana PATH already configured in $SHELL_PROFILE"
    fi
    
    # Add Rust/Cargo to PATH if not already present
    if ! grep -q "export PATH.*cargo" "$SHELL_PROFILE" 2>/dev/null; then
        {
            echo ""
            echo "# Rust/Cargo PATH"
            echo 'export PATH="$HOME/.cargo/bin:$PATH"'
        } >> "$SHELL_PROFILE"
        log_success "Added Rust/Cargo to $SHELL_PROFILE"
    else
        log_success "Rust/Cargo PATH already configured in $SHELL_PROFILE"
    fi
else
    log_warning "Could not detect shell profile. Please manually add PATH entries."
fi

# Create necessary directories
log_info "Creating necessary directories..."
safe_mkdir "$BACKUP_DIR"
safe_mkdir "$PROGRAMS_DIR"
safe_mkdir "$REPO_ROOT/logs"
log_success "Directories created"

echo ""
log_success "=========================================="
echo "Installation Complete!"
log_success "=========================================="
echo ""
echo "Installed versions:"
echo "  Rust: $(rustc --version 2>/dev/null || echo 'Not in PATH')"
echo "  Solana: $(solana --version 2>/dev/null || echo 'Not in PATH')"
echo "  Anchor: $(anchor --version 2>/dev/null || echo 'Not in PATH')"
echo ""
echo "Next steps:"
echo "1. Source your shell profile: source $SHELL_PROFILE"
echo "2. Run: ./scripts/setup-cluster.sh"
echo ""

