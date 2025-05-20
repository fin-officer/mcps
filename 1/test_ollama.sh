#!/bin/bash

source mcp_env/bin/activate
echo "Uruchamianie inspektora MCP dla serwera z Ollama..."
mcp dev mcp_server/server_ollama.py
