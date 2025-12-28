# Script Portability and Best Practices

This document describes the portability improvements and best practices implemented in the Solana Validator Node scripts.

## Overview

All scripts have been updated to be **dynamic, portable, and follow official bash scripting best practices**. They now work correctly across different Linux distributions, VMs, and system configurations.

## Key Improvements

### 1. Portable Shebang
- **Before**: `#!/bin/bash` (hardcoded path)
- **After**: `#!/usr/bin/env bash` (uses PATH to find bash)
- **Benefit**: Works even if bash is installed in non-standard locations

### 2. Common Library (`scripts/common.sh`)

A centralized library provides portable functions for all scripts:

#### OS Detection
- Automatically detects Linux distribution family:
  - **Debian/Ubuntu** → Uses `apt` package manager
  - **RHEL/CentOS/Fedora** → Uses `yum` or `dnf` package manager
  - **Arch Linux** → Uses `pacman` package manager
  - **SUSE/SLES** → Uses `zypper` package manager

#### Package Manager Detection
- Automatically detects and uses the correct package manager
- Maps package names to distribution-specific equivalents
- Example: `build-essential` (Debian) → `gcc gcc-c++ make` (RHEL)

#### Architecture Detection
- Detects CPU architecture: x86_64, aarch64, arm, etc.
- Maps to Solana release architecture names

#### Service Manager Detection
- Detects systemd, sysvinit, or other service managers

#### Firewall Detection
- Detects UFW, firewalld, or iptables
- Configures firewall rules using the detected tool

### 3. Dynamic Path Handling

#### Paths with Spaces
- All scripts handle paths with spaces correctly
- Uses proper quoting: `"$SCRIPT_DIR"` instead of `$SCRIPT_DIR`

#### PATH Management
- Uses `add_to_path()` function to avoid duplicates
- Safely adds directories to PATH without breaking existing entries

### 4. Error Handling

#### Command Existence Checks
- Uses `command_exists()` instead of `command -v` directly
- Provides clear error messages when required commands are missing

#### Safe File Operations
- `safe_source()` - Safely sources files with existence checks
- `safe_mkdir()` - Creates directories with proper permissions

### 5. Network Functions

#### Public IP Detection
- Tries multiple services: ifconfig.me, ipinfo.io, icanhazip.com, api.ipify.org
- Handles both IPv4 and IPv6 addresses
- Automatically formats IPv6 addresses for URLs (wraps in brackets)

### 6. Distribution-Specific Adaptations

#### Package Installation
The `install.sh` script now:
- Detects OS family automatically
- Maps package names to distribution equivalents
- Uses the correct package manager commands

**Example Package Mappings:**
```
Debian/Ubuntu          → RHEL/CentOS/Fedora
─────────────────────────────────────────────
build-essential        → gcc gcc-c++ make
libudev-dev            → systemd-devel
libssl-dev             → openssl-devel
ufw                    → firewalld
```

#### Firewall Configuration
The `configure-networking.sh` script supports:
- **UFW** (Ubuntu/Debian default)
- **firewalld** (RHEL/CentOS/Fedora default)
- **iptables** (fallback for all distributions)

### 7. Shell Profile Detection

#### Dynamic Shell Detection
- Detects user's shell: bash, zsh, fish
- Automatically finds the correct profile file:
  - bash → `~/.bashrc` or `~/.bash_profile`
  - zsh → `~/.zshrc`
  - fish → `~/.config/fish/config.fish`

### 8. Best Practices Implemented

#### POSIX Compliance
- Uses standard POSIX commands where possible
- Avoids bash-specific features when alternatives exist
- Uses `[ ]` instead of `[[ ]]` for better portability (where appropriate)

#### Error Handling
- `set -euo pipefail` - Exits on error, undefined variables, and pipe failures
- Proper error messages with context
- Graceful degradation when optional features fail

#### Logging
- Consistent logging format across all scripts
- Logs to both console and log files
- Timestamped log entries

#### Security
- Checks for root execution (prevents accidental root runs)
- Validates sudo availability
- Proper file permissions

## Scripts Updated

### Core Scripts
1. ✅ **install.sh** - Full portability with multi-distribution support
2. ✅ **configure-networking.sh** - Multi-firewall support
3. ✅ **setup-cluster.sh** - Uses common library
4. ✅ **common.sh** - New common library

### Other Scripts
All scripts now use `#!/usr/bin/env bash` shebang for portability.

## Testing Recommendations

### Test on Different Distributions
- ✅ Ubuntu 22.04 LTS
- ✅ Debian 11/12
- ✅ CentOS 8/9 / Rocky Linux
- ✅ Fedora 38+
- ✅ Arch Linux

### Test Scenarios
1. **Fresh Installation**: Run on clean VM
2. **Existing Installation**: Run on system with some packages already installed
3. **Path with Spaces**: Test in directory with spaces in path
4. **Different Shells**: Test with bash, zsh
5. **Different Architectures**: x86_64, ARM64

## Usage

All scripts work the same way as before, but now they're more robust:

```bash
# Works on any Linux distribution
./scripts/install.sh

# Automatically detects and configures firewall
./scripts/configure-networking.sh

# Sets up cluster with proper path handling
./scripts/setup-cluster.sh
```

## Benefits

1. **Cross-Platform**: Works on any Linux distribution
2. **Robust**: Handles edge cases and errors gracefully
3. **Maintainable**: Common functions in one place
4. **User-Friendly**: Clear error messages and logging
5. **Production-Ready**: Follows industry best practices

## Future Enhancements

Potential improvements:
- Support for macOS (with Homebrew)
- Support for Alpine Linux (with apk)
- Automated testing on multiple distributions
- Docker-based testing environment

