#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${YELLOW}Please run as root (use sudo)${NC}" 
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Print section header
print_section() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

# Print status message
print_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $1"
    else
        echo -e "${RED}[FAILED]${NC} $1"
    fi
}

# Install package with error handling
install_package() {
    local pkg_manager="$1"
    local pkg_name="$2"
    
    echo -e "Installing ${YELLOW}${pkg_name}${NC}..."
    if [ "$pkg_manager" = "apt-get" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg_name"
    elif [ "$pkg_manager" = "yum" ] || [ "$pkg_manager" = "dnf" ]; then
        "$pkg_manager" install -y "$pkg_name"
    elif [ "$pkg_manager" = "zypper" ]; then
        zypper --non-interactive install -y "$pkg_name"
    elif [ "$pkg_manager" = "pacman" ]; then
        pacman -S --noconfirm "$pkg_name"
    fi
    print_status "Installed $pkg_name"
}

# Setup Python virtual environment
setup_python_venv() {
    local venv_dir="$1"
    local requirements_file="$2"
    
    echo -e "\n${GREEN}=== Setting up Python virtual environment ===${NC}"
    
    # Create virtual environment
    if [ ! -d "$venv_dir" ]; then
        python3 -m venv "$venv_dir"
        print_status "Created virtual environment in $venv_dir"
    else
        echo -e "${YELLOW}Virtual environment already exists in $venv_dir${NC}"
    fi
    
    # Activate and upgrade pip
    source "$venv_dir/bin/activate"
    python3 -m pip install --upgrade pip
    
    # Install requirements if file exists
    if [ -f "$requirements_file" ]; then
        pip install -r "$requirements_file"
        print_status "Installed Python dependencies from $requirements_file"
    else
        echo -e "${YELLOW}Requirements file not found: $requirements_file${NC}"
    fi
    
    deactivate
}

# Setup Node.js environment
setup_nodejs() {
    local node_version="18.x"  # Default to LTS version
    
    echo -e "\n${GREEN}=== Setting up Node.js ===${NC}"
    
    if command_exists node && node --version | grep -q "v$node_version"; then
        echo -e "Node.js $node_version is already installed"
        return 0
    fi
    
    # Install Node Version Manager (nvm)
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        print_status "Installed NVM"
    fi
    
    # Load NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install Node.js
    nvm install "$node_version"
    nvm use "$node_version"
    nvm alias default node
    
    print_status "Node.js $node_version installed"
    
    # Install npm packages
    if [ -f "package.json" ]; then
        npm install
        print_status "Installed npm packages"
    fi
}

# Setup Docker
setup_docker() {
    if command_exists docker; then
        echo -e "${YELLOW}Docker is already installed${NC}"
        return 0
    fi
    
    echo -e "\n${GREEN}=== Installing Docker ===${NC}"
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Add current user to docker group
    usermod -aG docker "$USER"
    
    # Enable and start Docker service
    systemctl enable docker
    systemctl start docker
    
    print_status "Docker installed and service started"
}

# Install development tools
install_dev_tools() {
    local pkg_manager="$1"
    
    echo -e "\n${GREEN}=== Installing Development Tools ===${NC}"
    
    if [ "$pkg_manager" = "apt-get" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            build-essential \
            libssl-dev \
            zlib1g-dev \
            libbz2-dev \
            libreadline-dev \
            libsqlite3-dev \
            curl \
            llvm \
            libncurses5-dev \
            xz-utils \
            tk-dev \
            libxml2-dev \
            libxmlsec1-dev \
            libffi-dev \
            liblzma-dev \
            git \
            wget \
            unzip \
            jq \
            htop \
            tmux \
            vim
            
    elif [ "$pkg_manager" = "yum" ] || [ "$pkg_manager" = "dnf" ]; then
        "$pkg_manager" groupinstall -y "Development Tools"
        "$pkg_manager" install -y \
            openssl-devel \
            bzip2-devel \
            libffi-devel \
            sqlite-devel \
            xz \
            wget \
            curl \
            git \
            jq \
            htop \
            tmux \
            vim
            
    elif [ "$pkg_manager" = "zypper" ]; then
        zypper --non-interactive install -y -t pattern devel_basis
        zypper --non-interactive install -y \
            git \
            wget \
            curl \
            jq \
            htop \
            tmux \
            vim
            
    elif [ "$pkg_manager" = "pacman" ]; then
        pacman -S --noconfirm --needed \
            base-devel \
            git \
            wget \
            curl \
            jq \
            htop \
            tmux \
            vim
    fi
    
    print_status "Development tools installed"
}
