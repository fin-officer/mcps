#!/bin/bash
# Aktywacja środowiska wirtualnego jeśli istnieje
if [ -d "mcp_env" ]; then
    source mcp_env/bin/activate
fi

# Uruchomienie klienta z przekazanymi argumentami
python client2.py "$@"
