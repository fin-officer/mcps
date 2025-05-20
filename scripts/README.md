# Environment Setup Scripts

This directory contains scripts to set up a development environment for MCP servers on various Linux distributions.

## Available Setup Scripts

- `setup_environment.sh` - Main script that detects your Linux distribution and runs the appropriate setup script
- `linux/` - Distribution-specific setup scripts
  - `setup_ubuntu.sh` - For Debian/Ubuntu-based distributions
  - `setup_centos.sh` - For RHEL/CentOS-based distributions
  - `setup_fedora.sh` - For Fedora
  - `setup_opensuse.sh` - For openSUSE
  - `setup_arch.sh` - For Arch Linux and derivatives
  - `common.sh` - Common functions used by all setup scripts

## Usage

### Quick Start

1. Make the main setup script executable:
   ```bash
   chmod +x scripts/setup_environment.sh
   ```

2. Run the setup script as root:
   ```bash
   sudo scripts/setup_environment.sh
   ```

### Options

- `--with-docker` - Also install and configure Docker

### Examples

1. Basic setup (without Docker):
   ```bash
   sudo scripts/setup_environment.sh
   ```

2. Setup with Docker:
   ```bash
   sudo scripts/setup_environment.sh --with-docker
   ```

## What's Installed

The setup scripts will install and configure:

1. **System Packages**:
   - Development tools (build-essential, git, curl, wget, etc.)
   - Python 3 and pip
   - Node.js and npm
   - Docker (optional)

2. **User Setup**:
   - Creates a non-root user named `mcps` with sudo privileges
   - Configures environment variables

3. **Configuration**:
   - Sets up Python virtual environment
   - Configures npm to install packages globally without sudo
   - Sets up Docker (if requested)

## Manual Steps After Setup

After running the setup script, you should:

1. Log out and log back in for all changes to take effect
2. Run `source ~/.bashrc` to update your current shell
3. Set up your Git configuration:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

## Troubleshooting

### Permission Issues

If you encounter permission issues, try:

```bash
# Fix directory permissions
sudo chown -R $USER:$USER ~/.npm
sudo chown -R $USER:$USER ~/.config

# Fix npm permissions
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
```

### Node.js Version Issues

If you need a specific Node.js version:

```bash
# Using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 18  # or any other version
nvm use 18
```

### Python Virtual Environment

To create and activate a Python virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Supported Distributions

- Ubuntu/Debian
- CentOS/RHEL
- Fedora
- openSUSE
- Arch Linux

For other distributions, you may need to modify the setup scripts accordingly.
