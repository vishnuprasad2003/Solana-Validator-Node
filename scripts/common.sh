#!/usr/bin/env bash
#
# Common Library for Solana Validator Node Scripts
# Provides portable, cross-platform functions for all scripts
# Follows POSIX-compliant bash best practices
#

# Prevent multiple sourcing
if [ -n "${COMMON_LIB_LOADED:-}" ]; then
    return 0
fi
export COMMON_LIB_LOADED=1

# ============================================================================
# SHELL DETECTION AND COMPATIBILITY
# ============================================================================

# Detect shell and ensure bash compatibility
detect_shell() {
    local shell_name
    shell_name="${SHELL##*/}"
    echo "$shell_name"
}

# Ensure we're using bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script requires bash" >&2
    exit 1
fi

# ============================================================================
# OS DETECTION
# ============================================================================

detect_os() {
    local os_id os_version os_codename
    os_id=""
    os_version=""
    os_codename=""
    
    # Try /etc/os-release first (most modern)
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        os_id="${ID:-}"
        os_version="${VERSION_ID:-}"
        os_codename="${VERSION_CODENAME:-}"
        
        # Handle Ubuntu/Debian codename
        if [ -z "$os_codename" ] && [ -n "${UBUNTU_CODENAME:-}" ]; then
            os_codename="$UBUNTU_CODENAME"
        fi
    # Fallback to older methods
    elif [ -f /etc/redhat-release ]; then
        if grep -qi "centos" /etc/redhat-release; then
            os_id="centos"
            os_version=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
        elif grep -qi "red hat" /etc/redhat-release; then
            os_id="rhel"
            os_version=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
        fi
    elif [ -f /etc/debian_version ]; then
        os_id="debian"
        os_version=$(cat /etc/debian_version)
    elif [ -f /etc/arch-release ]; then
        os_id="arch"
    elif [ -f /etc/SuSE-release ]; then
        os_id="sles"
        os_version=$(grep VERSION /etc/SuSE-release | awk '{print $3}')
    fi
    
    # Normalize OS ID
    case "$os_id" in
        ubuntu|debian)
            echo "debian"
            ;;
        rhel|centos|rocky|almalinux|fedora|amazon)
            echo "rhel"
            ;;
        arch|manjaro)
            echo "arch"
            ;;
        sles|opensuse*)
            echo "sles"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get OS family
OS_FAMILY=$(detect_os)
export OS_FAMILY

# Get detailed OS info
get_os_info() {
    local os_id os_version os_codename
    os_id=""
    os_version=""
    os_codename=""
    
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        os_id="${ID:-}"
        os_version="${VERSION_ID:-}"
        os_codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
    fi
    
    echo "$os_id|$os_version|$os_codename"
}

# ============================================================================
# PACKAGE MANAGER DETECTION
# ============================================================================

detect_package_manager() {
    local pm=""
    
    case "$OS_FAMILY" in
        debian)
            if command -v apt-get >/dev/null 2>&1; then
                pm="apt"
            elif command -v apt >/dev/null 2>&1; then
                pm="apt"
            fi
            ;;
        rhel)
            if command -v dnf >/dev/null 2>&1; then
                pm="dnf"
            elif command -v yum >/dev/null 2>&1; then
                pm="yum"
            fi
            ;;
        arch)
            if command -v pacman >/dev/null 2>&1; then
                pm="pacman"
            fi
            ;;
        sles)
            if command -v zypper >/dev/null 2>&1; then
                pm="zypper"
            fi
            ;;
    esac
    
    echo "${pm:-unknown}"
}

# Get package manager
PACKAGE_MANAGER=$(detect_package_manager)
export PACKAGE_MANAGER

# ============================================================================
# ARCHITECTURE DETECTION
# ============================================================================

detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            echo "x86_64-unknown-linux-gnu"
            ;;
        aarch64|arm64)
            echo "aarch64-unknown-linux-gnu"
            ;;
        armv7l|armv6l)
            echo "arm-unknown-linux-gnueabihf"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get architecture
ARCHITECTURE=$(detect_architecture)
export ARCHITECTURE

# ============================================================================
# SERVICE MANAGER DETECTION
# ============================================================================

detect_service_manager() {
    if systemctl --version >/dev/null 2>&1; then
        echo "systemd"
    elif [ -d /etc/init.d ]; then
        echo "sysvinit"
    elif command -v service >/dev/null 2>&1; then
        echo "service"
    else
        echo "unknown"
    fi
}

# Get service manager
SERVICE_MANAGER=$(detect_service_manager)
export SERVICE_MANAGER

# ============================================================================
# FIREWALL DETECTION
# ============================================================================

detect_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        echo "ufw"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        echo "firewalld"
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
    else
        echo "none"
    fi
}

# Get firewall
FIREWALL=$(detect_firewall)
export FIREWALL

# ============================================================================
# PACKAGE MANAGEMENT FUNCTIONS
# ============================================================================

# Install packages using detected package manager
install_packages() {
    local packages=("$@")
    local failed=0
    
    case "$PACKAGE_MANAGER" in
        apt)
            sudo apt-get update -qq || true
            sudo apt-get install -y "${packages[@]}" || failed=1
            ;;
        dnf)
            sudo dnf install -y "${packages[@]}" || failed=1
            ;;
        yum)
            sudo yum install -y "${packages[@]}" || failed=1
            ;;
        pacman)
            sudo pacman -S --noconfirm "${packages[@]}" || failed=1
            ;;
        zypper)
            sudo zypper install -y "${packages[@]}" || failed=1
            ;;
        *)
            echo "Error: Unsupported package manager: $PACKAGE_MANAGER" >&2
            return 1
            ;;
    esac
    
    return $failed
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    
    case "$PACKAGE_MANAGER" in
        apt)
            dpkg -l | grep -q "^ii  $package " 2>/dev/null
            ;;
        dnf|yum)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Q "$package" >/dev/null 2>&1
            ;;
        zypper)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Update package lists
update_package_lists() {
    case "$PACKAGE_MANAGER" in
        apt)
            sudo apt-get update -qq || true
            ;;
        dnf)
            sudo dnf check-update -q || true
            ;;
        yum)
            sudo yum check-update -q || true
            ;;
        pacman)
            sudo pacman -Sy --noconfirm || true
            ;;
        zypper)
            sudo zypper refresh -q || true
            ;;
    esac
}

# ============================================================================
# COMMAND DETECTION
# ============================================================================

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Require command (exit if not found)
require_command() {
    local cmd="$1"
    local error_msg="${2:-Command $cmd is required but not found}"
    
    if ! command_exists "$cmd"; then
        echo "Error: $error_msg" >&2
        exit 1
    fi
}

# ============================================================================
# PATH HANDLING
# ============================================================================

# Safely add to PATH (avoid duplicates)
add_to_path() {
    local new_path="$1"
    local path_var="${2:-PATH}"
    
    if [ -z "${!path_var:-}" ]; then
        export "$path_var=$new_path"
    elif [[ ":${!path_var}:" != *":${new_path}:"* ]]; then
        export "$path_var=${new_path}:${!path_var}"
    fi
}

# ============================================================================
# NETWORK FUNCTIONS
# ============================================================================

# Detect public IP address
detect_public_ip() {
    local ip=""
    
    # Try multiple services
    for service in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "api.ipify.org"; do
        ip=$(curl -s --max-time 5 "https://$service" 2>/dev/null || curl -s --max-time 5 "http://$service" 2>/dev/null)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [[ "$ip" == *:* ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    return 1
}

# Format IP for URL (wrap IPv6 in brackets)
format_ip_for_url() {
    local ip="$1"
    if [[ "$ip" == *:* ]]; then
        echo "[$ip]"
    else
        echo "$ip"
    fi
}

# ============================================================================
# DIRECTORY FUNCTIONS
# ============================================================================

# Create directory with proper permissions
safe_mkdir() {
    local dir="$1"
    local perms="${2:-0755}"
    
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chmod "$perms" "$dir" 2>/dev/null || true
    fi
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# Safely source a file
safe_source() {
    local file="$1"
    if [ -f "$file" ] && [ -r "$file" ]; then
        # shellcheck source=/dev/null
        . "$file"
        return 0
    fi
    return 1
}

# ============================================================================
# LOGGING FUNCTIONS (to be overridden by scripts)
# ============================================================================

# Default logging functions (can be overridden)
log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[SUCCESS] $*"
}

log_warning() {
    echo "[WARNING] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Trap errors
set_error_trap() {
    set -eE
    trap 'error_handler $? $LINENO' ERR
}

error_handler() {
    local exit_code=$1
    local line_no=$2
    log_error "Error occurred at line $line_no with exit code $exit_code"
    exit $exit_code
}

# ============================================================================
# SUDO CHECK
# ============================================================================

# Check if sudo is available
check_sudo() {
    if ! command_exists sudo; then
        log_error "sudo is required but not found. Please install sudo or run as root."
        exit 1
    fi
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo privileges. You may be prompted for your password."
    fi
}

# ============================================================================
# ROOT CHECK
# ============================================================================

# Check if running as root (and exit if so, unless allowed)
check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

# Setup common environment variables
setup_environment() {
    # Ensure common directories exist
    safe_mkdir "$HOME/.local/share"
    safe_mkdir "$HOME/.config"
    
    # Add common paths
    add_to_path "$HOME/.local/bin"
    add_to_path "$HOME/.cargo/bin"
    add_to_path "$HOME/.local/share/solana/install/active_release/bin"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize common library
init_common() {
    # Setup environment
    setup_environment
    
    # Export detected values
    export OS_FAMILY
    export PACKAGE_MANAGER
    export ARCHITECTURE
    export SERVICE_MANAGER
    export FIREWALL
}

# Auto-initialize if not sourced from another script
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    init_common
    echo "OS Family: $OS_FAMILY"
    echo "Package Manager: $PACKAGE_MANAGER"
    echo "Architecture: $ARCHITECTURE"
    echo "Service Manager: $SERVICE_MANAGER"
    echo "Firewall: $FIREWALL"
fi

