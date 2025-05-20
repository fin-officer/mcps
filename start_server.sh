#!/bin/bash
# Script to start an MCP server from the local repository
# Usage: ./start_server.sh [server_name] [port]

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    # Load env vars safely without exporting lines with special characters
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        if [[ $key && ! $key =~ ^\s*# && ! -z $value ]]; then
            # Remove surrounding quotes if present
            value=$(echo $value | sed -e 's/^["'\'']\(.*\)["'\'']$/\1/')
            export $key="$value"
        fi
    done < .env
fi

# Function to check if a port is already in use
port_in_use() {
    local port=$1
    if command -v nc &> /dev/null; then
        nc -z $HOST $port &> /dev/null
        return $?
    elif command -v lsof &> /dev/null; then
        lsof -i:$port &> /dev/null
        return $?
    else
        # If neither nc nor lsof is available, assume port is free
        return 1
    fi
}

# Function to find a free port starting from a given port
find_free_port() {
    local start_port=$1
    local port=$start_port
    while port_in_use $port; do
        echo -e "${YELLOW}Port $port is already in use, trying next port...${NC}"
        port=$((port + 1))
    done
    echo $port
}

# Default values
HOST=${HOST:-0.0.0.0}
BASE_PORT=${PORT:-8010}
PORT=$(find_free_port $BASE_PORT)
DOCKER_PORT=$(find_free_port $((PORT + 1)))
EMAIL_PORT=$(find_free_port $((DOCKER_PORT + 1)))
FILESYSTEM_PORT=$(find_free_port $((EMAIL_PORT + 1)))
PUPPETEER_PORT=$(find_free_port $((FILESYSTEM_PORT + 1)))
WORKERS=${WORKERS:-4}
RELOAD=""
DEBUG=${DEBUG:-false}

# Enable reload in debug mode
if [ "$DEBUG" = "true" ] || [ "$DEBUG" = "True" ] || [ "$DEBUG" = "1" ]; then
    RELOAD="--reload"
    WORKERS=1
fi

# Function to start a Python server
start_python_server() {
    local name=$1
    local port_var=$2
    local default_port=$3
    local module=$4
    
    local port=${!port_var:-$default_port}
    
    echo -e "${GREEN}Starting ${name} MCP server (Python) on ${HOST}:${port} with ${WORKERS} workers...${NC}"
    
    if [ -n "$RELOAD" ]; then
        echo -e "${YELLOW}Running in development mode with auto-reload${NC}"
    fi
    
    # Start the server in the background
    (
        export PORT=$port
        uvicorn ${module}:app \
            --host $HOST \
            --port $port \
            --workers $WORKERS \
            $RELOAD \
            --log-level $(echo ${LOG_LEVEL:-info} | tr '[:upper:]' '[:lower:]')
    ) &
    
    # Store the PID
    pids+=($!)
}

# Function to start a Node.js server
start_node_server() {
    local name=$1
    local port_var=$2
    local default_port=$3
    local server_path=$4
    
    local port=${!port_var:-$default_port}
    
    echo -e "${GREEN}Starting ${name} MCP server (Node.js) on ${HOST}:${port}...${NC}"
    
    # Change to the server directory
    cd "$server_path"
    
    # Check if node_modules exists, if not install dependencies
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}Installing dependencies...${NC}"
        npm install
    fi
    
    # Start the server in the background
    (
        export PORT=$port
        npm start -- --port $port
    ) &
    
    # Store the PID
    pids+=($!)
    
    # Return to the original directory
    cd - > /dev/null
}

# Array to store PIDs
pids=()

# Start the main MCP server
(
    echo -e "${GREEN}Starting Main MCP server on ${HOST}:${PORT}...${NC}"
    # Start the main server
    python main.py docker --host $HOST --port $PORT || \
        echo -e "${RED}Failed to start Main MCP server. See error above.${NC}"
) &
pids+=($!)

# Start Docker MCP server if enabled
if [ "${DOCKER_ENABLED:-true}" = "true" ]; then
    (
        echo -e "${GREEN}Starting Docker MCP server on ${HOST}:${DOCKER_PORT}...${NC}"
        # Disable Docker TLS verification to avoid certificate errors
        export DOCKER_TLS_VERIFY=0
        export DOCKER_CERT_PATH=""
        # Explicitly set Docker host to unix socket
        export DOCKER_HOST="unix:///var/run/docker.sock"
        
        # Check if Docker socket exists
        if [ ! -S "/var/run/docker.sock" ]; then
            echo -e "${RED}Warning: Docker socket not found at /var/run/docker.sock${NC}"
            echo -e "${YELLOW}Docker MCP server may not work correctly. Is Docker installed and running?${NC}"
        fi
        
        # Start the Docker server
        python main.py docker --host $HOST --port $DOCKER_PORT || \
            echo -e "${RED}Failed to start Docker MCP server. See error above.${NC}"
    ) &
    pids+=($!)
fi

# Start Email MCP server if enabled
if [ "${EMAIL_ENABLED:-true}" = "true" ]; then
    (
        echo -e "${GREEN}Starting Email MCP server on ${HOST}:${EMAIL_PORT}...${NC}"
        
        # Check if SMTP server is configured
        if [ -z "$SMTP_SERVER" ]; then
            echo -e "${YELLOW}Warning: SMTP_SERVER not set. Email functionality may be limited.${NC}"
        fi
        
        # Start the Email server
        python main.py email --host $HOST --port $EMAIL_PORT || \
            echo -e "${RED}Failed to start Email MCP server. See error above.${NC}"
    ) &
    pids+=($!)
fi

# Start Filesystem MCP server if enabled
if [ "${FILESYSTEM_ENABLED:-true}" = "true" ]; then
    (
        echo -e "${GREEN}Starting Filesystem MCP server (Node.js)...${NC}"
        cd "$(pwd)/servers/src/filesystem"
        
        # Check if node_modules exists, if not install dependencies
        if [ ! -d "node_modules" ]; then
            echo -e "${YELLOW}Installing dependencies...${NC}"
            npm install
        fi
        
        # Start the server
        export PORT=${FILESYSTEM_PORT:-8006}
        # Build the project if dist directory doesn't exist or is empty
        if [ ! -d "dist" ] || [ -z "$(ls -A dist 2>/dev/null)" ]; then
            echo -e "${YELLOW}Building Filesystem server...${NC}"
            npm run build
        fi
        
        # Create a data directory if it doesn't exist
        DATA_DIR="$(pwd)/data"
        mkdir -p "$DATA_DIR"
        
        # Check if dist/index.js exists after building
        if [ -f "dist/index.js" ]; then
            echo -e "${GREEN}Running Filesystem server from dist/index.js${NC}"
            echo -e "${GREEN}Allowed directory: $DATA_DIR${NC}"
            node dist/index.js "$DATA_DIR"
        elif [ -f "index.ts" ]; then
            # If TypeScript is used, run with ts-node or npx tsx
            echo -e "${YELLOW}Running Filesystem server directly from TypeScript...${NC}"
            echo -e "${GREEN}Allowed directory: $DATA_DIR${NC}"
            if command -v npx &> /dev/null; then
                # Pass the port as an environment variable and the allowed directory as an argument
                npx tsx index.ts "$DATA_DIR"
            else
                echo -e "${RED}Error: TypeScript file found but npx is not available. Please install Node.js with npm.${NC}"
                exit 1
            fi
        elif [ -f "index.js" ]; then
            # If JavaScript is used, run with node
            node index.js
        else
            echo -e "${RED}Error: No entry point found for Filesystem server.${NC}"
            exit 1
        fi
    ) &
    pids+=($!)
fi

# Start Puppeteer MCP server if enabled
if [ "${PUPPETEER_ENABLED:-true}" = "true" ]; then
    (
        echo -e "${GREEN}Starting Puppeteer MCP server on ${HOST}:${PUPPETEER_PORT}...${NC}"
        cd "$(pwd)"
        export PORT=$PUPPETEER_PORT
        export PYTHONPATH="$(pwd)":"$PYTHONPATH"
        
        # Check if Node.js is installed (required for Puppeteer)
        if ! command -v node &> /dev/null; then
            echo -e "${YELLOW}Warning: Node.js not found. Puppeteer MCP server requires Node.js to be installed.${NC}"
        fi
        
        # Start the Puppeteer server
        uvicorn mcp.servers.puppeteer.main:app --host $HOST --port $PUPPETEER_PORT $RELOAD \
            --log-level $(echo ${LOG_LEVEL:-info} | tr '[:upper:]' '[:lower:]') || \
            echo -e "${RED}Failed to start Puppeteer MCP server. See error above.${NC}"
    ) &
    pids+=($!)
fi

# Function to handle shutdown
shutdown_servers() {
    echo -e "\n${YELLOW}Shutting down servers...${NC}"
    for pid in "${pids[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            kill -TERM $pid
        fi
    done
    wait
    echo -e "${GREEN}All servers have been stopped.${NC}"
    exit 0
}

# Set up trap to catch termination signals
trap 'shutdown_servers' INT TERM

# Keep the script running and wait for all background processes
wait
