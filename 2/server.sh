#!/bin/bash

# Prosty skrypt uruchamiający minimalny serwer MCP z TinyLLM
# Autor: Tom
# Data: 2025-05-20

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}   Minimalny serwer MCP z TinyLLM via Ollama         ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Aktywacja środowiska wirtualnego jeśli istnieje
if [ -d "mcp_env" ]; then
    echo -e "${BLUE}Aktywacja środowiska wirtualnego...${NC}"
    source mcp_env/bin/activate
fi

# Sprawdzenie wymaganych pakietów Python
required_packages=("mcp" "requests")
missing_packages=()

for package in "${required_packages[@]}"; do
    if ! pip show $package &>/dev/null; then
        missing_packages+=("$package")
    fi
done

if [ ${#missing_packages[@]} -gt 0 ]; then
    echo -e "${YELLOW}Instalacja brakujących pakietów: ${missing_packages[*]}${NC}"
    pip install ${missing_packages[*]}
fi

# Sprawdzenie czy Ollama jest zainstalowana
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}UWAGA: Ollama nie jest zainstalowana${NC}"
    echo -e "${YELLOW}Pobierz ją ze strony: https://ollama.com/download${NC}"
else
    echo -e "${GREEN}✓ Ollama jest zainstalowana${NC}"

    # Sprawdzenie czy serwer Ollama jest uruchomiony
    if curl -s --head --connect-timeout 2 http://localhost:11434 > /dev/null; then
        echo -e "${GREEN}✓ Serwer Ollama jest uruchomiony${NC}"
    else
        echo -e "${RED}✗ Serwer Ollama nie jest uruchomiony${NC}"
        echo -e "${YELLOW}Uruchamianie serwera Ollama w nowym terminalu...${NC}"

        # Próba otwarcia nowego terminala z serwerem Ollama
        gnome-terminal -- bash -c "ollama serve; read -p 'Naciśnij Enter, aby zamknąć...'" || \
        xterm -e "ollama serve; read -p 'Naciśnij Enter, aby zamknąć...'" || \
        konsole --new-tab -e "ollama serve; read -p 'Naciśnij Enter, aby zamknąć...'" || \
        (
            echo -e "${RED}Nie udało się uruchomić nowego terminala${NC}"
            echo -e "${YELLOW}Uruchom Ollama ręcznie w nowym terminalu komendą:${NC} ollama serve"
            read -p "Naciśnij Enter, gdy serwer Ollama będzie uruchomiony..." dummy
        )
    fi

    # Sprawdzenie czy model tinyllama jest dostępny
    if ollama list 2>/dev/null | grep -q tinyllama; then
        echo -e "${GREEN}✓ Model tinyllama jest dostępny${NC}"
    else
        echo -e "${RED}✗ Model tinyllama nie jest dostępny${NC}"
        echo -e "${YELLOW}Pobieranie modelu tinyllama...${NC}"
        ollama pull tinyllama
    fi
fi

# Utworzenie plików serwera i klienta jeśli nie istnieją
if [ ! -f "minimal_mcp_ollama.py" ]; then
    echo -e "${BLUE}Tworzenie pliku serwera MCP...${NC}"
    cat > minimal_mcp_ollama.py << 'EOL'
#!/usr/bin/env python3
"""
Minimalistyczny serwer MCP z integracją Ollama TinyLLM
Wszystko w jednym pliku dla maksymalnej prostoty
"""

import os
import sys
import requests
from mcp.server.fastmcp import FastMCP, Context

# Konfiguracja
OLLAMA_URL = "http://localhost:11434"
MODEL_NAME = "tinyllama"  # Nazwę modelu można zmienić

def check_ollama_available():
    """Sprawdza, czy Ollama jest dostępna i model załadowany."""
    try:
        # Sprawdzenie, czy serwer Ollama działa
        response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=2)
        if response.status_code != 200:
            print(f"⚠️ Błąd: Serwer Ollama nie odpowiada poprawnie. Kod: {response.status_code}")
            return False

        # Sprawdzenie, czy wymagany model jest dostępny
        models = response.json().get("models", [])
        if not any(model["name"] == MODEL_NAME for model in models):
            print(f"⚠️ Model {MODEL_NAME} nie jest dostępny. Dostępne modele:")
            for model in models:
                print(f" - {model['name']}")
            print(f"\nZainstaluj model komendą: ollama pull {MODEL_NAME}")
            return False

        print(f"✅ Ollama działa poprawnie, model {MODEL_NAME} jest dostępny")
        return True
    except requests.exceptions.ConnectionError:
        print("⚠️ Błąd: Nie można połączyć się z serwerem Ollama (port 11434)")
        print("ℹ️ Uruchom Ollama komendą: ollama serve")
        return False
    except Exception as e:
        print(f"⚠️ Błąd: {str(e)}")
        return False

# Tworzenie serwera MCP
mcp = FastMCP("MCP-Ollama-TinyLLM")

@mcp.tool()
async def ask_tinyllm(prompt: str, ctx: Context = None) -> str:
    """Zadaj pytanie do modelu TinyLLM poprzez Ollama."""
    if ctx:
        await ctx.info(f"Wysyłanie zapytania do modelu TinyLLM: {prompt[:50]}...")

    try:
        # Wywołanie API Ollama z minimalną konfiguracją
        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": MODEL_NAME,
                "prompt": prompt,
                "temperature": 0.7,
                "max_tokens": 1000
            },
            timeout=60
        )

        if response.status_code == 200:
            result = response.json()
            return result.get("response", "Brak odpowiedzi od modelu.")
        else:
            error_msg = f"Błąd Ollama: {response.status_code}"
            if ctx:
                await ctx.error(error_msg)
            return error_msg
    except Exception as e:
        error_msg = f"Błąd: {str(e)}"
        if ctx:
            await ctx.error(error_msg)
        return error_msg

@mcp.tool()
def echo(message: str) -> str:
    """Proste narzędzie do testowania działania serwera."""
    return f"Otrzymano: {message}"

if __name__ == "__main__":
    print("🚀 Uruchamianie minimalnego serwera MCP z TinyLLM...")

    # Sprawdzenie dostępności Ollama przed uruchomieniem
    if not check_ollama_available():
        choice = input("Czy chcesz kontynuować mimo to? (t/n): ")
        if choice.lower() != 't':
            print("Zamykanie...")
            sys.exit(1)

    # Uruchomienie serwera MCP
    print("🔌 Uruchamianie serwera MCP na porcie 8000...")
    print("ℹ️ Dostępne narzędzia: ask_tinyllm, echo")

    # Przykładowe zapytania:
    print("\n📝 Przykłady użycia:")
    print("curl -X POST -H \"Content-Type: application/json\" -d '{\"name\":\"echo\",\"arguments\":{\"message\":\"Test\"}}' http://localhost:8000/v1/tools")
    print("curl -X POST -H \"Content-Type: application/json\" -d '{\"name\":\"ask_tinyllm\",\"arguments\":{\"prompt\":\"Co to jest Python?\"}}' http://localhost:8000/v1/tools")

    mcp.run()
EOL
    chmod +x minimal_mcp_ollama.py
fi

if [ ! -f "minimal_mcp_client.py" ]; then
    echo -e "${BLUE}Tworzenie pliku klienta MCP...${NC}"
    cat > minimal_mcp_client.py << 'EOL'
#!/usr/bin/env python3
"""
Minimalistyczny klient MCP do komunikacji z serwerem TinyLLM
"""

import sys
import requests
import argparse

def send_query(prompt, tool="ask_tinyllm", server_url="http://localhost:8000"):
    """
    Wysyła zapytanie do serwera MCP.

    Args:
        prompt: Zapytanie do modelu
        tool: Nazwa narzędzia (domyślnie ask_tinyllm)
        server_url: URL serwera MCP

    Returns:
        Odpowiedź lub komunikat o błędzie
    """
    print(f"📤 Wysyłanie zapytania do {tool}: {prompt[:50]}...")

    try:
        # Zapytanie do API serwera MCP
        response = requests.post(
            f"{server_url}/v1/tools",
            json={
                "name": tool,
                "arguments": {"prompt" if tool == "ask_tinyllm" else "message": prompt}
            },
            timeout=120  # Dłuższy timeout dla modeli językowych
        )

        if response.status_code == 200:
            result = response.json()
            if "result" in result:
                return result["result"]
            elif "error" in result:
                return f"Błąd: {result['error']}"
            else:
                return "Nieznany format odpowiedzi"
        else:
            return f"Błąd odpowiedzi: {response.status_code} - {response.text}"
    except requests.exceptions.ConnectionError:
        return "⚠️ Błąd połączenia z serwerem MCP. Sprawdź czy serwer jest uruchomiony."
    except Exception as e:
        return f"⚠️ Błąd: {str(e)}"

def main():
    """Główna funkcja klienta."""
    # Parsowanie argumentów wiersza poleceń
    parser = argparse.ArgumentParser(description="Minimalistyczny klient MCP dla TinyLLM")
    parser.add_argument("prompt", help="Zapytanie do wysłania do modelu")
    parser.add_argument("--tool", default="ask_tinyllm", help="Narzędzie do użycia (domyślnie: ask_tinyllm)")
    parser.add_argument("--server", default="http://localhost:8000", help="URL serwera MCP")
    args = parser.parse_args()

    # Wysłanie zapytania
    response = send_query(args.prompt, args.tool, args.server)

    # Wyświetlenie odpowiedzi
    print("\n📥 Odpowiedź:")
    print("=" * 50)
    print(response)
    print("=" * 50)

if __name__ == "__main__":
    main()
EOL
    chmod +x minimal_mcp_client.py
fi

# Tworzenie skryptu do używania klienta
if [ ! -f "ask_tinyllm.sh" ]; then
    echo -e "${BLUE}Tworzenie skryptu klienta...${NC}"
    cat > ask.sh << 'EOL'
#!/bin/bash
# Aktywacja środowiska wirtualnego jeśli istnieje
if [ -d "mcp_env" ]; then
    source mcp_env/bin/activate
fi

# Uruchomienie klienta z przekazanymi argumentami
python minimal_mcp_client.py "$@"
EOL
    chmod +x ask.sh
fi

# Uruchomienie serwera MCP
echo -e "${GREEN}Uruchamianie serwera MCP z TinyLLM...${NC}"
echo -e "${YELLOW}Aby zadać pytanie w nowym terminalu, użyj:${NC}"
echo -e "${BLUE}./ask_tinyllm.sh \"Twoje pytanie\"${NC}"
echo

# Uruchomienie serwera
python minimal_mcp_ollama.py