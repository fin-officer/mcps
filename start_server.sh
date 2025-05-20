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
    export $(grep -v '^#' .env | xargs)
fi

# Default values
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8000}
WORKERS=${WORKERS:-4}
RELOAD=""
DEBUG=${DEBUG:-false}

# Enable reload in debug mode
if [ "$DEBUG" = "true" ] || [ "$DEBUG" = "True" ] || [ "$DEBUG" = "1" ]; then
    RELOAD="--reload"
    WORKERS=1
fi

# Function to start a server
start_server() {
    local name=$1
    local port_var=$2
    local default_port=$3
    local module=$4
    
    local port=${!port_var:-$default_port}
    
    echo -e "${GREEN}Starting ${name} MCP server on ${HOST}:${port} with ${WORKERS} workers...${NC}"
    
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
            --log-level ${LOG_LEVEL:-info}
    ) &
    
    # Store the PID
    pids+=($!)
}

# Array to store PIDs
pids=()

# Start the main MCP server
start_server "Main" PORT $PORT "mcp.main:app"

# Start Docker MCP server if enabled
if [ "${DOCKER_ENABLED:-true}" = "true" ]; then
    start_server "Docker" DOCKER_PORT ${DOCKER_PORT:-8001} "mcp.servers.docker:app"
fi

# Start Email MCP server if enabled
if [ "${EMAIL_ENABLED:-true}" = "true" ] && [ -n "$SMTP_SERVER" ]; then
    start_server "Email" EMAIL_PORT ${EMAIL_PORT:-8002} "mcp.servers.email:app"
fi

# Start Filesystem MCP server if enabled
if [ "${FILESYSTEM_ENABLED:-true}" = "true" ]; then
    start_server "Filesystem" FILESYSTEM_PORT ${FILESYSTEM_PORT:-8003} "mcp.servers.filesystem:app"
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
