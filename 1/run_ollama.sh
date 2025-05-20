#!/bin/bash

source mcp_env/bin/activate
echo "Uruchamianie serwera MCP z Ollama..."
python mcp_server/server_ollama.py
