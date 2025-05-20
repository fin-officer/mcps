#!/bin/bash

# Exit on error
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Check if running as root
check_root

print_section "Updating system packages"
pacman -Syu --noconfirm
print_status "Updated system packages"

# Install development tools
print_section "Installing development tools"
pacman -S --noconfirm --needed base-devel git wget curl jq htop tmux vim

# Setup Python
print_section "Setting up Python"
pacman -S --noconfirm --needed python python-pip

# Setup Node.js
print_section "Setting up Node.js"
if ! command_exists node; then
    pacman -S --noconfirm --needed nodejs npm
    npm install -g npm@latest
    print_status "Node.js and npm installed"
else
    echo -e "${YELLOW}Node.js is already installed${NC}"
fi

# Setup Yay (AUR helper) if not installed
if ! command_exists yay; then
    print_section "Installing Yay (AUR helper)"
    pacman -S --noconfirm --needed --asdeps base-devel git
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    chown -R $SUDO_USER:users yay
    cd yay
    sudo -u $SUDO_USER makepkg -si --noconfirm
    cd ~
    print_status "Yay installed"
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
    usermod -aG wheel,users "$USERNAME"
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
