#!/bin/bash

# Exit on error
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Check if running as root
check_root

# Determine package manager (yum or dnf)
if command_exists dnf; then
    PKG_MANAGER="dnf"
    PKG_INSTALL="dnf install -y"
else
    PKG_MANAGER="yum"
    PKG_INSTALL="yum install -y"
fi

print_section "Updating system packages"
$PKG_MANAGER update -y
print_status "Updated system packages"

# Install EPEL repository
if ! rpm -q epel-release; then
    print_section "Installing EPEL repository"
    $PKG_INSTALL epel-release
    print_status "EPEL repository installed"
else
    echo -e "${YELLOW}EPEL repository is already installed${NC}"
fi

# Install development tools
print_section "Installing development tools"
$PKG_MANAGER groupinstall -y "Development Tools"
install_dev_tools "$PKG_MANAGER"

# Setup Python
print_section "Setting up Python"
$PKG_INSTALL python3 python3-pip python3-devel

# Setup Node.js
print_section "Setting up Node.js"
if ! command_exists node; then
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    $PKG_INSTALL nodejs
    npm install -g npm@latest
    print_status "Node.js and npm installed"
else
    echo -e "${YELLOW}Node.js is already installed${NC}"
fi

# Setup Docker (optional)
if [ "$1" = "--with-docker" ]; then
    setup_docker
fi

# Create a non-root user if it doesn't exist
USERNAME="mcps"
if ! id "$USERNAME" &>/dev/null; then
    print_section "Creating non-root user"
    useradd -m -s /bin/bash "$USERNAME"
    usermod -aG wheel "$USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/$USERNAME"
    chmod 0440 "/etc/sudoers.d/$USERNAME"
    print_status "Created non-root user: $USERNAME"
    
    # Set password for the new user
    echo -e "${YELLOW}Setting password for user $USERNAME${NC}"
    passwd "$USERNAME"
else
    echo -e "${YELLOW}User $USERNAME already exists${NC}"
fi

# Configure SELinux if enabled
if command_exists sestatus && sestatus | grep -q "enabled"; then
    print_section "Configuring SELinux"
    setsebool -P httpd_can_network_connect 1
    print_status "SELinux configured"
fi

print_section "Environment setup completed successfully!"
echo -e "${GREEN}Please log out and log back in for all changes to take effect.${NC}"
echo -e "${GREEN}Then run 'source ~/.bashrc' to update your current shell.${NC}"
