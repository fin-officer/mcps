#!/bin/bash

# Prosty skrypt testowy do komunikacji z Ollama przez CLI
# Nie wymaga MCP - tylko czysty test Ollama

echo "==== Test CLI dla Ollama ===="

# Sprawdzenie czy Ollama jest zainstalowana
if ! command -v ollama &> /dev/null; then
    echo "Błąd: Ollama nie jest zainstalowana."
    echo "Możesz ją zainstalować ze strony: https://ollama.com/download"
    exit 1
fi

# Sprawdzenie czy serwer Ollama działa
if ! curl -s --head --connect-timeout 2 http://localhost:11434 > /dev/null; then
    echo "Błąd: Serwer Ollama nie jest uruchomiony."
    echo "Uruchom go w nowym terminalu komendą: ollama serve"
    exit 1
fi

# Listowanie dostępnych modeli
echo "Dostępne modele Ollama:"
ollama list

# Sprawdzenie czy wymagany model jest zainstalowany
if ! ollama list | grep -q tinyllama; then
    echo ""
    echo "Model tinyllama nie jest zainstalowany."
    read -p "Czy chcesz go pobrać teraz? (t/n): " download_model

    if [[ "$download_model" == "t" ]]; then
        echo "Pobieranie modelu tinyllama..."
        ollama pull tinyllama
    else
        echo "Test zostanie przeprowadzony na innym dostępnym modelu."
    fi
fi

# Wybór modelu do testu
echo ""
echo "Dostępne modele:"
ollama list | awk '{print NR ".", $1}'

read -p "Wybierz numer modelu do testu: " model_number
selected_model=$(ollama list | awk -v line="$model_number" 'NR==line {print $1}')

if [[ -z "$selected_model" ]]; then
    echo "Nieprawidłowy wybór. Używanie pierwszego dostępnego modelu."
    selected_model=$(ollama list | awk 'NR==1 {print $1}')
fi

echo "Wybrany model: $selected_model"

# Wykonanie szybkiego testu z modelem
echo ""
echo "Wykonywanie prostego testu z modelem $selected_model..."
ollama run $selected_model "Napisz krótką odpowiedź (max 15 słów) na pytanie: Co to jest sztuczna inteligencja?"

# Utworzenie skryptu Pythona dla bardziej szczegółowego testu
cat > test_ollama_api.py << 'EOL'
import argparse
import requests
import json
import time

def test_ollama_api(model_name):
    """
    Testuje API Ollama z podanym modelem.

    Args:
        model_name: Nazwa modelu do użycia
    """
    base_url = "http://localhost:11434/api"

    print(f"\n=== Test API Ollama z modelem {model_name} ===\n")

    # Sprawdzenie informacji o modelu
    try:
        response = requests.get(f"{base_url}/tags")
        if response.status_code == 200:
            models = response.json().get("models", [])

            # Sprawdzenie czy wybrany model jest dostępny
            model_exists = any(model["name"] == model_name for model in models)

            if model_exists:
                print(f"Model {model_name} jest dostępny.")
            else:
                print(f"UWAGA: Model {model_name} nie jest dostępny. Dostępne modele:")
                for model in models:
                    print(f" - {model['name']}")
                return False
        else:
            print(f"Błąd podczas sprawdzania modeli: {response.status_code}")
            return False
    except Exception as e:
        print(f"Błąd podczas komunikacji z API Ollama: {str(e)}")
        return False

    # Wysłanie zapytania
    prompt = "Co to jest Python? Odpowiedz w 2-3 zdaniach."

    try:
        print(f"\nWysyłanie zapytania: '{prompt}'")

        # Parametry generacji
        params = {
            "model": model_name,
            "prompt": prompt,
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": 100,
            "stream": False
        }

        start_time = time.time()

        # Wywołanie API
        response = requests.post(f"{base_url}/generate", json=params)

        end_time = time.time()

        if response.status_code == 200:
            result = response.json()
            print(f"\nOdpowiedź (czas: {end_time - start_time:.2f}s):")
            print(f"-" * 50)
            print(result.get("response", "Brak odpowiedzi"))
            print(f"-" * 50)
            print(f"Tokeny wejściowe: {result.get('prompt_eval_count', 'N/A')}")
            print(f"Tokeny wyjściowe: {result.get('eval_count', 'N/A')}")
            return True
        else:
            print(f"Błąd odpowiedzi: {response.status_code}")
            print(f"Treść: {response.text}")
            return False
    except Exception as e:
        print(f"Błąd podczas komunikacji z API Ollama: {str(e)}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test API Ollama")
    parser.add_argument("model", help="Nazwa modelu do testowania")
    args = parser.parse_args()

    test_ollama_api(args.model)
EOL

# Instalacja wymaganych pakietów Python
pip install requests >/dev/null 2>&1

# Uruchomienie testu API
echo ""
echo "Uruchamianie testu API Ollama..."
python test_ollama_api.py "$selected_model"

# Sprawdzenie poziomu zaawansowania testu
echo ""
read -p "Czy chcesz uruchomić zaawansowany test strumieniowania? (t/n): " stream_test
if [[ "$stream_test" == "t" ]]; then
    cat > test_ollama_stream.py << 'EOL'
import argparse
import requests
import json
import time
import sys

def test_ollama_streaming(model_name):
    """
    Testuje strumieniowe API Ollama z podanym modelem.

    Args:
        model_name: Nazwa modelu do użycia
    """
    base_url = "http://localhost:11434/api"

    print(f"\n=== Test strumieniowego API Ollama z modelem {model_name} ===\n")

    # Wysłanie zapytania
    prompt = "Napisz krótkie opowiadanie o misiu, który lubi miód. Max 100 słów."

    try:
        print(f"Wysyłanie zapytania: '{prompt}'")
        print(f"Strumieniowa odpowiedź:\n{'-' * 50}")

        # Parametry generacji
        params = {
            "model": model_name,
            "prompt": prompt,
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": 200,
            "stream": True
        }

        start_time = time.time()

        # Wywołanie API w trybie strumieniowym
        with requests.post(f"{base_url}/generate", json=params, stream=True) as response:
            if response.status_code != 200:
                print(f"Błąd odpowiedzi: {response.status_code}")
                print(f"Treść: {response.text}")
                return False

            total_tokens = 0

            # Przetwarzanie strumieniowej odpowiedzi
            for line in response.iter_lines():
                if line:
                    try:
                        chunk = json.loads(line)
                        response_piece = chunk.get("response", "")
                        sys.stdout.write(response_piece)
                        sys.stdout.flush()

                        # Zliczanie tokenów
                        if "eval_count" in chunk:
                            total_tokens = chunk["eval_count"]

                        # Sprawdzanie zakończenia
                        if chunk.get("done", False):
                            break
                    except json.JSONDecodeError:
                        print(f"Błąd dekodowania JSON: {line}")

        end_time = time.time()

        print(f"\n{'-' * 50}")
        print(f"Czas generacji: {end_time - start_time:.2f}s")
        print(f"Wygenerowane tokeny: {total_tokens}")
        return True

    except Exception as e:
        print(f"Błąd podczas komunikacji z API Ollama: {str(e)}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test strumieniowego API Ollama")
    parser.add_argument("model", help="Nazwa modelu do testowania")
    args = parser.parse_args()

    test_ollama_streaming(args.model)
EOL

    # Uruchomienie testu strumieniowania
    python test_ollama_stream.py "$selected_model"
fi

echo ""
echo "==== Test Ollama zakończony ===="
echo ""
echo "Możesz używać Ollama z komendą:"
echo "ollama run $selected_model \"Twoje zapytanie\""
echo ""
echo "Lub przez API (port 11434)"