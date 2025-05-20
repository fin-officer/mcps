#!/bin/bash

# Skrypt do instalacji narzędzia uv

echo "Instalacja uv - nowoczesnego menedżera pakietów Python..."

# Metoda instalacji zależy od systemu operacyjnego
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    curl -sSf https://astral.sh/uv/install.sh | bash
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    curl -sSf https://astral.sh/uv/install.sh | bash
else
    # Inne (Windows z Git Bash, itp.)
    echo "Automatyczna instalacja nie jest dostępna dla twojego systemu."
    echo "Odwiedź https://github.com/astral-sh/uv aby zainstalować ręcznie."
    exit 1
fi

echo "Instalacja uv zakończona. Uruchom ponownie terminal, aby uzyskać dostęp do polecenia uv."
echo "Następnie uruchom ponownie ./test.sh"