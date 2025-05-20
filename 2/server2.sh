#!/bin/bash

# Super prosty skrypt startowy dla serwera i klienta TinyLLM
# Autor: Tom
# Data: 2025-05-20

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}   Super prosty serwer i klient TinyLLM via Ollama    ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Aktywacja środowiska wirtualnego jeśli istnieje
if [ -d "mcp_env" ]; then
    echo -e "${BLUE}Aktywacja środowiska wirtualnego...${NC}"
    source mcp_env/bin/activate
fi

# Uruchomienie serwera w tle
echo -e "${GREEN}Uruchamianie serwera TinyLLM...${NC}"
echo -e "${YELLOW}Aby zadać pytanie, użyj skryptu:${NC}"
echo -e "${BLUE}./ask_tinyllm_simple.sh \"Twoje pytanie\"${NC}"
echo -e "${YELLOW}Lub w przeglądarce otwórz:${NC} http://localhost:5000"
echo

# Uruchomienie serwera
python server.py
 Sprawdzenie wymaganych pakietów Python
required_packages=("flask" "requests")
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
if [ ! -f "server.py" ]; then
    echo -e "${BLUE}Tworzenie pliku serwera...${NC}"
    cat > server.py << 'EOL'
#!/usr/bin/env python3
"""
Super prosty serwer HTTP udostępniający TinyLLM przez Ollama.
Bez zależności od MCP - używa tylko standardowej biblioteki Flask.
"""

import os
import sys
import json
import requests
from flask import Flask, request, jsonify

# Konfiguracja
OLLAMA_URL = "http://localhost:11434"
MODEL_NAME = "tinyllama"  # Nazwę modelu można zmienić
PORT = 5000

app = Flask(__name__)

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

@app.route('/', methods=['GET'])
def home():
    """Strona główna z instrukcjami."""
    return """
    <html>
    <head>
        <title>Super prosty serwer TinyLLM</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
            pre { background: #f4f4f4; padding: 10px; border-radius: 5px; }
            .endpoint { font-weight: bold; color: #4CAF50; }
        </style>
    </head>
    <body>
        <h1>Super prosty serwer TinyLLM</h1>
        <p>Dostępne endpointy:</p>

        <h2 class="endpoint">POST /ask</h2>
        <p>Zadaj pytanie do modelu TinyLLM.</p>
        <pre>
curl -X POST -H "Content-Type: application/json" \\
     -d '{"prompt": "Co to jest Python?"}' \\
     http://localhost:5000/ask
        </pre>

        <h2 class="endpoint">POST /echo</h2>
        <p>Proste narzędzie do testów - odbija wiadomość.</p>
        <pre>
curl -X POST -H "Content-Type: application/json" \\
     -d '{"message": "Test"}' \\
     http://localhost:5000/echo
        </pre>

        <h2>Status serwera Ollama</h2>
        <p>Model: <strong>tinyllama</strong></p>
        <p>URL Ollama: <strong>http://localhost:11434</strong></p>
    </body>
    </html>
    """

@app.route('/ask', methods=['POST'])
def ask_tinyllm():
    """Zadaj pytanie do modelu TinyLLM poprzez Ollama."""
    if not request.is_json:
        return jsonify({"error": "Oczekiwano danych JSON"}), 400

    data = request.get_json()
    if 'prompt' not in data:
        return jsonify({"error": "Brak parametru 'prompt'"}), 400

    prompt = data['prompt']

    print(f"📤 Zapytanie: {prompt[:50]}...")

    try:
        # Wywołanie API Ollama z minimalną konfiguracją
        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": MODEL_NAME,
                "prompt": prompt,
                "temperature": data.get('temperature', 0.7),
                "max_tokens": data.get('max_tokens', 1000)
            },
            timeout=60
        )

        if response.status_code == 200:
            result = response.json()
            print(f"📥 Odpowiedź otrzymana")
            return jsonify({"response": result.get("response", "Brak odpowiedzi od modelu.")})
        else:
            error_msg = f"Błąd Ollama: {response.status_code}"
            print(f"⚠️ {error_msg}")
            return jsonify({"error": error_msg}), 500
    except Exception as e:
        error_msg = f"Błąd: {str(e)}"
        print(f"⚠️ {error_msg}")
        return jsonify({"error": error_msg}), 500

@app.route('/echo', methods=['POST'])
def echo():
    """Proste narzędzie do testowania działania serwera."""
    if not request.is_json:
        return jsonify({"error": "Oczekiwano danych JSON"}), 400

    data = request.get_json()
    if 'message' not in data:
        return jsonify({"error": "Brak parametru 'message'"}), 400

    return jsonify({"response": f"Otrzymano: {data['message']}"})

if __name__ == "__main__":
    print("🚀 Uruchamianie super prostego serwera TinyLLM...")

    # Sprawdzenie dostępności Ollama przed uruchomieniem
    if not check_ollama_available():
        choice = input("Czy chcesz kontynuować mimo to? (t/n): ")
        if choice.lower() != 't':
            print("Zamykanie...")
            sys.exit(1)

    # Uruchomienie serwera
    print(f"🔌 Uruchamianie serwera na porcie {PORT}...")
    print("ℹ️ Dostępne endpointy: /ask, /echo")

    # Przykładowe zapytania:
    print("\n📝 Przykłady użycia:")
    print(f"curl -X POST -H \"Content-Type: application/json\" -d '{{\"message\": \"Test\"}}' http://localhost:{PORT}/echo")
    print(f"curl -X POST -H \"Content-Type: application/json\" -d '{{\"prompt\": \"Co to jest Python?\"}}' http://localhost:{PORT}/ask")

    # Uruchomienie serwera na wszystkich interfejsach
    app.run(host='0.0.0.0', port=PORT, debug=False)
EOL
    chmod +x server.py
fi

if [ ! -f "client2.py" ]; then
    echo -e "${BLUE}Tworzenie pliku klienta...${NC}"
    cat > client2.py << 'EOL'
#!/usr/bin/env python3
"""
Super prosty klient do komunikacji z serwerem TinyLLM.
Nie wymaga żadnych specjalnych bibliotek poza requests.
"""

import sys
import requests
import argparse

def send_query(prompt, server_url="http://localhost:5000"):
    """
    Wysyła zapytanie do serwera TinyLLM.

    Args:
        prompt: Zapytanie do modelu
        server_url: URL serwera

    Returns:
        Odpowiedź lub komunikat o błędzie
    """
    print(f"📤 Wysyłanie zapytania: {prompt[:50]}...")

    try:
        # Zapytanie do API serwera
        response = requests.post(
            f"{server_url}/ask",
            json={"prompt": prompt},
            timeout=120  # Dłuższy timeout dla modeli językowych
        )

        if response.status_code == 200:
            result = response.json()
            if "response" in result:
                return result["response"]
            elif "error" in result:
                return f"Błąd: {result['error']}"
            else:
                return "Nieznany format odpowiedzi"
        else:
            return f"Błąd odpowiedzi: {response.status_code} - {response.text}"
    except requests.exceptions.ConnectionError:
        return "⚠️ Błąd połączenia z serwerem. Sprawdź czy serwer jest uruchomiony."
    except Exception as e:
        return f"⚠️ Błąd: {str(e)}"

def test_echo(message="Test", server_url="http://localhost:5000"):
    """
    Testuje działanie serwera używając endpointu echo.

    Args:
        message: Wiadomość testowa
        server_url: URL serwera

    Returns:
        True jeśli test się powiódł, False w przeciwnym razie
    """
    print(f"🧪 Testowanie serwera za pomocą echo...")

    try:
        response = requests.post(
            f"{server_url}/echo",
            json={"message": message},
            timeout=5
        )

        if response.status_code == 200:
            result = response.json()
            print(f"✅ Odpowiedź serwera: {result.get('response', '')}")
            return True
        else:
            print(f"❌ Błąd odpowiedzi: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Błąd: {str(e)}")
        return False

def main():
    """Główna funkcja klienta."""
    # Parsowanie argumentów wiersza poleceń
    parser = argparse.ArgumentParser(description="Super prosty klient TinyLLM")
    parser.add_argument("prompt", nargs='?', help="Zapytanie do wysłania do modelu")
    parser.add_argument("--server", default="http://localhost:5000", help="URL serwera (domyślnie: http://localhost:5000)")
    parser.add_argument("--test", action="store_true", help="Testuje połączenie z serwerem")
    args = parser.parse_args()

    # Jeśli podano opcję --test, wykonaj test echo
    if args.test:
        test_success = test_echo(server_url=args.server)
        if not test_success:
            print("❌ Test nie powiódł się. Czy serwer jest uruchomiony?")
            sys.exit(1)
        print("✅ Test zakończony pomyślnie!")

        # Jeśli nie podano zapytania, zakończ po teście
        if not args.prompt:
            sys.exit(0)

    # Sprawdź czy podano zapytanie
    if not args.prompt:
        parser.print_help()
        sys.exit(1)

    # Wysłanie zapytania
    response = send_query(args.prompt, args.server)

    # Wyświetlenie odpowiedzi
    print("\n📥 Odpowiedź:")
    print("=" * 50)
    print(response)
    print("=" * 50)

if __name__ == "__main__":
    main()
EOL
    chmod +x client2.py
fi

# Tworzenie skryptu do używania klienta
if [ ! -f "ask_tinyllm_simple.sh" ]; then
    echo -e "${BLUE}Tworzenie skryptu klienta...${NC}"
    cat > ask_tinyllm_simple.sh << 'EOL'
#!/bin/bash
# Aktywacja środowiska wirtualnego jeśli istnieje
if [ -d "mcp_env" ]; then
    source mcp_env/bin/activate
fi

# Uruchomienie klienta z przekazanymi argumentami
python client2.py "$@"
EOL
    chmod +x ask_tinyllm_simple.sh
fi

# Test połączenia z serwerem Ollama
echo -e "${BLUE}Testowanie połączenia z Ollama...${NC}"
if curl -s --head --connect-timeout 2 http://localhost:11434 > /dev/null; then
    echo -e "${GREEN}Połączenie z Ollama działa poprawnie.${NC}"
else
    echo -e "${RED}Nie można połączyć się z Ollama. Czy serwer jest uruchomiony?${NC}"
    read -p "Czy chcesz kontynuować mimo to? (t/n): " continue_choice
    if [[ "$continue_choice" != "t" ]]; then
        echo "Zatrzymywanie."
        exit 1
    fi
fi

#