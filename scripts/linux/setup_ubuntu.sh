#!/bin/bash

# Exit on error
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Check if running as root
check_root

print_section "Updating package lists"
apt-get update
print_status "Updated package lists"

# Install prerequisites
print_section "Installing prerequisites"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg-agent \
    lsb-release
print_status "Installed prerequisites"

# Install development tools
install_dev_tools "apt-get"

# Setup Python
print_section "Setting up Python"
install_package "apt-get" "python3-venv"
install_package "apt-get" "python3-pip"
install_package "apt-get" "python3-dev"

# Setup Node.js
print_section "Setting up Node.js"
if ! command_exists node; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    install_package "apt-get" "nodejs"
    install_package "apt-get" "npm"
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
    usermod -aG sudo "$USERNAME"
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
