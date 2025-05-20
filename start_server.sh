#!/bin/bash
# Script to start an MCP server from the local repository
# Usage: ./start_server.sh [server_name] [port]

set -e

SERVER_NAME=${1:-filesystem}
PORT=${2:-8000}

# Change to the servers directory
cd "$(dirname "$0")/servers"

# Check if the server exists
if [ ! -d "src/$SERVER_NAME" ]; then
    echo "Error: Server '$SERVER_NAME' not found in src/"
    echo "Available servers:"
    ls -1 src/
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

echo "Starting $SERVER_NAME MCP server on port $PORT..."

# Start the server using local installation
cd "src/$SERVER_NAME"
npm start -- --port "$PORT"

# Alternative if the above doesn't work:
# node ../../node_modules/.bin/tsx src/index.ts --port "$PORT"
