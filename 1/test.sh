#!/bin/bash

# Aktywacja środowiska wirtualnego
source mcp_env/bin/activate

# Uruchomienie serwera MCP z inspektorem, używając komend pip zamiast uv
mcp dev mcp_server/server.py