#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Please run as root (use sudo)${NC}" 
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to detect Linux distribution
detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif type lsb_release >/dev/null 2>&1; then
        lsb_release -is | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# Function to run the appropriate setup script
run_setup_script() {
    local distro=$1
    local setup_script="${SCRIPT_DIR}/linux/setup_${distro}.sh"
    
    if [ -f "$setup_script" ]; then
        echo -e "${GREEN}Running setup script for ${distro}...${NC}"
        chmod +x "$setup_script"
        "$setup_script" "$@"
    else
        echo -e "${RED}Unsupported Linux distribution: ${distro}${NC}"
        echo -e "${YELLOW}Please check the scripts/linux/ directory for available setup scripts.${NC}"
        exit 1
    fi
}

# Main execution
print_section() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

print_section "Detecting Linux distribution..."
DISTRO=$(detect_linux_distro)
echo -e "Detected distribution: ${GREEN}${DISTRO}${NC}"

# Map common distribution names to script names
case $DISTRO in
    ubuntu|debian|linuxmint|pop|elementary|kali|parrot|zorin)
        run_setup_script "ubuntu" "$@"
        ;;
    centos|rhel|redhat|fedora|amzn|amazon)
        if [ "$DISTRO" = "fedora" ]; then
            run_setup_script "fedora" "$@"
        else
            run_setup_script "centos" "$@"
        fi
        ;;
    opensuse*|suse*|sles)
        run_setup_script "opensuse" "$@"
        ;;
    arch|manjaro|endeavouros|garuda)
        run_setup_script "arch" "$@"
        ;;
    *)
        echo -e "${RED}Unsupported Linux distribution: ${DISTRO}${NC}"
        echo -e "${YELLOW}Please check the scripts/linux/ directory for available setup scripts.${NC}"
        exit 1
        ;;
esac
