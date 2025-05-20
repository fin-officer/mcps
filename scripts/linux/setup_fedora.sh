#!/bin/bash

# Exit on error
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Check if running as root
check_root

print_section "Updating system packages"
dnf update -y
print_status "Updated system packages"

# Install development tools
print_section "Installing development tools"
dnf groupinstall -y "Development Tools"
install_dev_tools "dnf"

# Setup Python
print_section "Setting up Python"
dnf install -y python3 python3-pip python3-devel

# Setup Node.js
print_section "Setting up Node.js"
if ! command_exists node; then
    dnf install -y nodejs npm
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

print_section "Environment setup completed successfully!"
echo -e "${GREEN}Please log out and log back in for all changes to take effect.${NC}"
echo -e "${GREEN}Then run 'source ~/.bashrc' to update your current shell.${NC}"
