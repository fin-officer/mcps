#!/bin/bash

# Skrypt testowy dla MCP 1.9.0
# Dostosowany do starszego API MCP

# Aktywacja środowiska wirtualnego
source mcp_env/bin/activate

echo "==== Test MCP 1.9.0 ===="
echo "Ten skrypt jest przystosowany do specyficznej wersji API MCP 1.9.0"

# Tworzenie testowego środowiska
mkdir -p mcp_server/data

# Tworzenie serwera MCP kompatybilnego z MCP 1.9.0
cat > mcp_server/compat_server.py << 'EOL'
from mcp.server.fastmcp import FastMCP

# Tworzenie serwera MCP
mcp = FastMCP("Prosty serwer MCP 1.9.0")

# Proste narzędzie
@mcp.tool()
def echo(message: str) -> str:
    """Zwraca otrzymaną wiadomość."""
    print(f"Echo: {message}")
    return f"Echo: {message}"

# Uruchomienie serwera
if __name__ == "__main__":
    print("Uruchamianie serwera MCP 1.9.0...")
    mcp.run()
EOL

# Uruchomienie serwera w tle
echo "Uruchamianie serwera MCP w tle..."
python mcp_server/compat_server.py &
SERVER_PID=$!

# Daj serwerowi czas na uruchomienie
echo "Czekanie na uruchomienie serwera..."
sleep 3

# Wykonanie bezpośredniego testu za pomocą mcp CLI
echo "Testowanie serwera za pomocą mcp CLI..."
echo

echo "Listowanie dostępnych narzędzi:"
# Użyj zapisanego PID do znalezienia portu serwera
ps -p $SERVER_PID -o args | grep -oP 'port=\K\d+' || echo "Nie można znaleźć portu, używanie domyślnego 8000"

# Próba bezpośredniego wywołania CLI
echo "Próba wywołania narzędzia echo za pomocą curl:"
curl -s -X POST -H "Content-Type: application/json" -d '{"name":"echo","arguments":{"message":"Test z curl"}}' http://localhost:8000/v1/tools | jq 2>/dev/null || echo "Nie można wykonać zapytania curl lub jq nie jest zainstalowane"

# Testowanie za pomocą Pythona
echo
echo "Testowanie za pomocą bezpośredniego skryptu Pythona:"
cat > mcp_direct_test.py << 'EOL'
import requests
import json

def test_mcp_tool():
    """Testuje bezpośrednie wywołanie narzędzia MCP przez API REST."""
    try:
        # Próba wykonania zapytania do serwera
        response = requests.post(
            "http://localhost:8000/v1/tools",
            json={
                "name": "echo",
                "arguments": {"message": "Test z Pythona"}
            }
        )

        print(f"Status: {response.status_code}")

        if response.status_code == 200:
            result = response.json()
            print(f"Odpowiedź: {result}")
            return True
        else:
            print(f"Błąd odpowiedzi: {response.text}")
            return False
    except Exception as e:
        print(f"Błąd podczas testu: {str(e)}")
        return False

if __name__ == "__main__":
    test_mcp_tool()
EOL

# Instalacja requests jeśli nie jest już zainstalowany
pip install requests 2>/dev/null

# Uruchomienie testu Pythona
python mcp_direct_test.py

# Zakończenie procesu serwera
echo
echo "Zakończenie procesu serwera..."
kill $SERVER_PID

# Tworzenie skryptu uruchamiającego serwer MCP
cat > run_mcp_server.sh << 'EOL'
#!/bin/bash
source mcp_env/bin/activate
echo "Uruchamianie serwera MCP 1.9.0..."
python mcp_server/compat_server.py
EOL
chmod +x run_mcp_server.sh

# Informacja o tworzeniu serwera MCP z integracją Ollama
echo
echo "Tworzenie serwera MCP z integracją Ollama..."

cat > mcp_server/ollama_basic.py << 'EOL'
import os
import requests
import json
from mcp.server.fastmcp import FastMCP

# Tworzenie serwera MCP
mcp = FastMCP("Serwer MCP z Ollama (Wersja 1.9.0)")

# Konfiguracja Ollama
OLLAMA_CONFIG = {
    "base_url": "http://localhost:11434",
    "model": "tinyllama",  # Można zmienić na inny model
    "temperature": 0.7,
    "max_tokens": 1000
}

# Funkcja pomocnicza do komunikacji z Ollama
def query_ollama(prompt):
    """Wysyła zapytanie do Ollama i zwraca odpowiedź."""
    try:
        response = requests.post(
            f"{OLLAMA_CONFIG['base_url']}/api/generate",
            json={
                "model": OLLAMA_CONFIG["model"],
                "prompt": prompt,
                "temperature": OLLAMA_CONFIG["temperature"],
                "max_tokens": OLLAMA_CONFIG["max_tokens"]
            }
        )

        if response.status_code == 200:
            return response.json().get("response", "Brak odpowiedzi od modelu")
        else:
            return f"Błąd odpowiedzi z Ollama: {response.status_code}"
    except Exception as e:
        return f"Błąd komunikacji z Ollama: {str(e)}"

# Narzędzie Ollama
@mcp.tool()
def ollama_ask(prompt: str) -> str:
    """Zadaj pytanie do modelu Ollama."""
    print(f"Wysyłanie zapytania do Ollama: {prompt[:50]}...")
    response = query_ollama(prompt)
    return response

# Proste narzędzie echo
@mcp.tool()
def echo(message: str) -> str:
    """Zwraca otrzymaną wiadomość."""
    return f"Echo: {message}"

# Uruchomienie serwera
if __name__ == "__main__":
    print("Uruchamianie serwera MCP z integracją Ollama...")
    print(f"Model Ollama: {OLLAMA_CONFIG['model']}")
    mcp.run()
EOL

# Tworzenie skryptu uruchamiającego serwer z Ollama
cat > run_ollama_server.sh << 'EOL'
#!/bin/bash
source mcp_env/bin/activate
echo "Sprawdzanie, czy Ollama jest uruchomiona..."
if curl -s --head --connect-timeout 2 http://localhost:11434 > /dev/null; then
    echo "Serwer Ollama jest uruchomiony."
else
    echo "UWAGA: Serwer Ollama nie jest uruchomiony."
    echo "Uruchom go w nowym terminalu komendą: ollama serve"
    read -p "Naciśnij Enter, aby kontynuować mimo to..." dummy
fi
echo "Uruchamianie serwera MCP z integracją Ollama..."
python mcp_server/ollama_basic.py
EOL
chmod +x run_ollama_server.sh

echo
echo "==== Test zakończony ===="
echo
echo "Możesz teraz uruchomić jeden z następujących serwerów:"
echo "1. Prosty serwer MCP: ./run_mcp_server.sh"
echo "2. Serwer MCP z integracją Ollama: ./run_ollama_server.sh"
echo
echo "Serwer będzie dostępny na porcie 8000, możesz wysyłać zapytania za pomocą:"
echo "curl -X POST -H \"Content-Type: application/json\" -d '{\"name\":\"echo\",\"arguments\":{\"message\":\"Test\"}}' http://localhost:8000/v1/tools"