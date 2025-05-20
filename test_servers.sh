#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables from .env if it exists
if [ -f .env ]; then
    # Load env vars safely without exporting lines with special characters
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        if [[ $key && ! $key =~ ^\s*# && ! -z $value ]]; then
            # Remove surrounding quotes if present
            value=$(echo $value | sed -e 's/^["\'\'](.*)["\'\']/\1/')
            export $key="$value"
        fi
    done < .env
fi

# Default values
HOST=${HOST:-localhost}
PORT=${PORT:-8000}
DOCKER_PORT=${DOCKER_PORT:-8004}
EMAIL_PORT=${EMAIL_PORT:-8005}
FILESYSTEM_PORT=${FILESYSTEM_PORT:-8006}

# Function to test a server
test_server() {
    local name=$1
    local url=$2
    local endpoint=$3
    local payload=$4
    
    echo -e "\n${YELLOW}Testing ${name} server at ${url}${NC}"
    
    # Test health endpoint
    echo -e "${YELLOW}Testing health endpoint...${NC}"
    health_response=$(curl -s -o /dev/null -w "%{http_code}" "${url}/health")
    
    if [ "$health_response" = "200" ]; then
        echo -e "${GREEN}Health check successful!${NC}"
    else
        echo -e "${RED}Health check failed with status code: ${health_response}${NC}"
    fi
    
    # Test MCP endpoint
    if [ -n "$endpoint" ] && [ -n "$payload" ]; then
        echo -e "${YELLOW}Testing MCP endpoint: ${endpoint}...${NC}"
        response=$(curl -s -X POST "${url}/mcp/${endpoint}" \
            -H "Content-Type: application/json" \
            -d "${payload}")
        
        echo -e "${GREEN}Response:${NC} $response"
    fi
}

# Test main server
test_server "Main" "http://${HOST}:${PORT}" "" ""

# Test Docker server
test_server "Docker" "http://${HOST}:${DOCKER_PORT}" "docker.containers.list" '{"all": true}'

# Test Email server
test_server "Email" "http://${HOST}:${EMAIL_PORT}" "" ""

# Test Filesystem server
test_server "Filesystem" "http://${HOST}:${FILESYSTEM_PORT}" "filesystem.listDirectory" '{"path": "/"}'

echo -e "\n${GREEN}Testing complete!${NC}"
