#!/bin/bash

#############################################
# OpenFortiVPN Package Installer
# Multi-Distro Linux Support
# Author: RezkyCoder
# Date: $(date +%Y-%m-%d)
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "$1"
    echo "=================================================="
    echo -e "${NC}"
}

# Detect Linux distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        DISTRO_NAME=$NAME
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
        DISTRO_NAME=$DISTRIB_DESCRIPTION
    else
        DISTRO="unknown"
        VERSION="unknown"
        DISTRO_NAME="Unknown Linux"
    fi
}

# Install OpenFortiVPN based on distro
install_openfortivpn() {
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop)
            print_info "Detected: $DISTRO_NAME"
            print_info "Installing via APT..."
            
            # Update package list
            sudo apt-get update
            
            # Install dependencies
            sudo apt-get install -y openfortivpn ppp resolvconf
            
            print_success "OpenFortiVPN installed successfully!"
            ;;
            
        fedora|rhel|centos|rocky|almalinux)
            print_info "Detected: $DISTRO_NAME"
            print_info "Installing via DNF/YUM..."
            
            # Determine package manager
            if command -v dnf &> /dev/null; then
                PKG_MGR="dnf"
            else
                PKG_MGR="yum"
            fi
            
            # Install EPEL if needed (for RHEL/CentOS)
            if [[ "$DISTRO" =~ ^(rhel|centos|rocky|almalinux)$ ]]; then
                if ! rpm -q epel-release &> /dev/null; then
                    print_info "Installing EPEL repository..."
                    sudo $PKG_MGR install -y epel-release
                fi
            fi
            
            # Install packages
            sudo $PKG_MGR install -y openfortivpn ppp
            
            print_success "OpenFortiVPN installed successfully!"
            ;;
            
        arch|manjaro|endeavouros)
            print_info "Detected: $DISTRO_NAME"
            print_info "Installing via Pacman..."
            
            # Update package db
            sudo pacman -Sy
            
            # Install packages
            sudo pacman -S --noconfirm openfortivpn ppp
            
            print_success "OpenFortiVPN installed successfully!"
            ;;
            
        opensuse*|sles)
            print_info "Detected: $DISTRO_NAME"
            print_info "Installing via Zypper..."
            
            # Refresh repos
            sudo zypper refresh
            
            # Install packages
            sudo zypper install -y openfortivpn ppp
            
            print_success "OpenFortiVPN installed successfully!"
            ;;
            
        alpine)
            print_info "Detected: $DISTRO_NAME"
            print_info "Installing via APK..."
            
            # Update package index
            sudo apk update
            
            # Install packages
            sudo apk add openfortivpn ppp
            
            print_success "OpenFortiVPN installed successfully!"
            ;;
            
        gentoo)
            print_info "Detected: $DISTRO_NAME"
            print_info "Installing via Portage..."
            
            # Sync portage tree
            sudo emerge --sync
            
            # Install packages
            sudo emerge --ask net-vpn/openfortivpn net-dialup/ppp
            
            print_success "OpenFortiVPN installed successfully!"
            ;;
            
        *)
            print_error "Unsupported distribution: $DISTRO_NAME"
            echo ""
            echo "Supported distributions:"
            echo "  - Ubuntu / Debian / Linux Mint / Pop!_OS"
            echo "  - Fedora / RHEL / CentOS / Rocky / AlmaLinux"
            echo "  - Arch Linux / Manjaro / EndeavourOS"
            echo "  - openSUSE / SLES"
            echo "  - Alpine Linux"
            echo "  - Gentoo"
            echo ""
            echo "Please install OpenFortiVPN manually:"
            echo "  https://github.com/adrienverge/openfortivpn"
            exit 1
            ;;
    esac
}

# Main
clear
print_header "OpenFortiVPN Package Installer"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "Don't run this script as root!"
   echo "Run as regular user with sudo privileges"
   exit 1
fi

# Detect distro
print_info "Detecting Linux distribution..."
detect_distro

echo ""
print_info "Distribution: $DISTRO_NAME"
print_info "Version: $VERSION"
echo ""

# Check if already installed
if command -v openfortivpn &> /dev/null; then
    print_warning "OpenFortiVPN is already installed!"
    echo ""
    openfortivpn --version
    echo ""
    read -p "Reinstall/Update? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation skipped"
        exit 0
    fi
fi

# Confirm installation
read -p "Install OpenFortiVPN and dependencies? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Installation cancelled"
    exit 0
fi

echo ""

# Install
install_openfortivpn

# Verify installation
echo ""
print_header "Verification"

if command -v openfortivpn &> /dev/null; then
    print_success "Installation verified!"
    echo ""
    openfortivpn --version
    echo ""
    
    print_info "OpenFortiVPN is ready to use!"
    echo ""
    echo "Next steps:"
    echo "  1. Run the main installer: bash install-openfortivpn.sh"
    echo "  2. Or configure manually: sudo vim /etc/openfortivpn/config.conf"
else
    print_error "Installation failed!"
    echo "Please check the error messages above"
    exit 1
fi

print_success "Done! 🎉"
echo ""
