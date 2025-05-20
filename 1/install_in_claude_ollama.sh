#!/bin/bash

source mcp_env/bin/activate
echo "Instalowanie serwera MCP z obsługą Ollama w Claude Desktop..."
mcp install mcp_server/server_ollama.py --name "MCP Server z Ollama Tiny"
