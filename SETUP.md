# MCP Server Setup Guide

This guide will help you set up and run the MCP (Model Context Protocol) servers.

## Prerequisites

1. **Node.js** (v16 or later)
   ```bash
   # On Ubuntu/Debian
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   
   # Or using nvm (Node Version Manager)
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
   nvm install --lts
   ```

2. **Python** (3.8 or later)
   ```bash
   # On Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y python3 python3-pip python3-venv
   ```

3. **Docker** (optional, for Docker MCP server)
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/mcps.git
   cd mcps
   ```

2. **Set up Python virtual environment**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Install Node.js dependencies**
   ```bash
   cd servers
   npm install
   cd ..
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

## Running MCP Servers

### Option 1: Using the start script (recommended)

```bash
# Start the filesystem server on port 8000
./start_server.sh filesystem 8000

# In a new terminal, start another server (e.g., git)
./start_server.sh git 8001
```

### Option 2: Manual startup

1. **Filesystem Server**
   ```bash
   cd servers/src/filesystem
   npm start -- --port 8000
   ```

2. **Git Server**
   ```bash
   cd servers/src/git
   npm start -- --port 8001
   ```

## Using the Python Client

1. **Install Python dependencies**
   ```bash
   pip install httpx pydantic python-dotenv
   ```

2. **Example usage**
   ```python
   from mcp.client import MCPClient
   import asyncio

   async def example():
       async with MCPClient("http://localhost:8000") as client:
           # List files in current directory
           response = await client.call(
               resource_type="filesystem",
               action="listDirectory",
               params={"path": "."}
           )
           print(response.data)

   asyncio.run(example())
   ```

## Troubleshooting

### Node.js/npm issues

- **Error: Cannot find module**
  ```bash
  cd servers
  rm -rf node_modules package-lock.json
  npm install
  ```

- **Port already in use**
  ```bash
  # Find and kill the process
  sudo lsof -i :8000
  kill -9 <PID>
  ```

### Python issues

- **Module not found**
  ```bash
  # Make sure you're in the virtual environment
  source .venv/bin/activate
  pip install -r requirements.txt
  ```

## Available Servers

- `filesystem` - File system operations
- `git` - Git repository management
- `postgres` - PostgreSQL database access
- `puppeteer` - Web automation
- `slack` - Slack integration
- `memory` - In-memory data storage
- `sequentialthinking` - AI reasoning

Each server has its own documentation in `servers/src/<server_name>/README.md`.
