#!/usr/bin/env python3
"""
Naprawiony serwer dla TinyLLM via Ollama.
Obsługuje problemy z parsowaniem JSON z Ollama.
"""

import os
import sys
import json
import traceback
import requests
from flask import Flask, request, jsonify

# Konfiguracja
OLLAMA_URL = "http://localhost:11434"
MODEL_NAME = "tinyllama:latest"  # Użycie pełnej nazwy z tagiem
PORT = 5001

app = Flask(__name__)


def check_ollama_available():
    """Sprawdza, czy Ollama jest dostępna i model załadowany."""
    try:
        # Sprawdzenie, czy serwer Ollama działa
        response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        if response.status_code != 200:
            print(f"⚠️ Błąd: Serwer Ollama nie odpowiada poprawnie. Kod: {response.status_code}")
            return False

        # Sprawdzenie, czy wymagany model jest dostępny
        models = response.json().get("models", [])
        model_exists = False
        for model in models:
            if model["name"] == MODEL_NAME or model["name"].startswith(MODEL_NAME.split(':')[0]):
                model_exists = True
                break

        if not model_exists:
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
            .warning { color: #f44336; }
        </style>
    </head>
    <body>
        <h1>Super prosty serwer TinyLLM</h1>
        <p>Dostępne endpointy:</p>

        <h2 class="endpoint">POST /ask</h2>
        <p>Zadaj pytanie do modelu TinyLLM.</p>
        <pre>
curl -X POST -H "Content-Type: application/json" \\
     -d '{"prompt":"Co to jest Python?"}' \\
     http://localhost:5001/ask
        </pre>

        <p class="warning">UWAGA: Zwróć uwagę na format JSON - musi być w jednej linii bez białych znaków!</p>

        <h2 class="endpoint">POST /echo</h2>
        <p>Proste narzędzie do testów - odbija wiadomość.</p>
        <pre>
curl -X POST -H "Content-Type: application/json" \\
     -d '{"message":"Test"}' \\
     http://localhost:5001/echo
        </pre>

        <h2>Status serwera Ollama</h2>
        <p>Model: <strong>tinyllama:latest</strong></p>
        <p>URL Ollama: <strong>http://localhost:11434</strong></p>

        <h2>Łatwiejsze zapytania</h2>
        <p>Możesz użyć skryptu pomocniczego do zapytań:</p>
        <pre>
./ask.sh "Twoje pytanie"
        </pre>
    </body>
    </html>
    """


def call_ollama_api(prompt, temperature=0.7, max_tokens=1000):
    """
    Bezpieczne wywołanie API Ollama z obsługą błędów.

    Args:
        prompt: Zapytanie do modelu
        temperature: Temperatura generowania
        max_tokens: Maksymalna liczba tokenów w odpowiedzi

    Returns:
        str: Odpowiedź od modelu lub komunikat o błędzie
    """
    try:
        # Użycie stream=False, aby uniknąć problemów z parsowaniem JSON
        payload = {
            "model": MODEL_NAME,
            "prompt": prompt,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": False
        }

        print(f"📤 Wysyłanie zapytania do Ollama: {json.dumps(payload)[:200]}...")

        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json=payload,
            timeout=60
        )

        # Sprawdzenie statusu odpowiedzi
        if response.status_code != 200:
            error_msg = f"Błąd Ollama: Kod {response.status_code}"
            print(f"⚠️ {error_msg}")
            return None, error_msg

        # Próba parsowania odpowiedzi jako JSON
        try:
            # Tylko pierwszy wiersz treści odpowiedzi
            first_line = response.text.strip().split('\n')[0]
            result = json.loads(first_line)
            ollama_response = result.get("response", "")
            print(f"📥 Odpowiedź Ollama (długość: {len(ollama_response)} znaków)")
            return ollama_response, None
        except json.JSONDecodeError as e:
            # Jeśli parsowanie nie powiodło się, wyświetl surowe dane
            print(f"⚠️ Błąd parsowania JSON: {str(e)}")
            print(f"Surowa odpowiedź: {response.text[:200]}...")

            # Spróbuj wyciągnąć tekst odpowiedzi bez polegania na JSON
            try:
                # Ręczne parsowanie dla strumieniowej odpowiedzi
                text_content = ""
                for line in response.text.strip().split('\n'):
                    try:
                        chunk = json.loads(line)
                        if "response" in chunk:
                            text_content += chunk["response"]
                    except:
                        pass

                if text_content:
                    print(f"📥 Odpowiedź wyodrębniona ręcznie (długość: {len(text_content)} znaków)")
                    return text_content, None
            except Exception as parsing_ex:
                print(f"⚠️ Nie można wyodrębnić odpowiedzi: {str(parsing_ex)}")

            # Jeśli wszystko zawiedzie, zwróć błąd
            return None, f"Błąd parsowania odpowiedzi Ollama: {str(e)}"
    except requests.exceptions.Timeout:
        error_msg = "Timeout podczas oczekiwania na odpowiedź z Ollama"
        print(f"⚠️ {error_msg}")
        return None, error_msg
    except Exception as e:
        error_msg = f"Nieoczekiwany błąd: {str(e)}"
        print(f"⚠️ {error_msg}")
        traceback.print_exc()
        return None, error_msg


@app.route('/ask', methods=['POST'])
def ask_tinyllm():
    """Zadaj pytanie do modelu TinyLLM poprzez Ollama."""
    # Debugowanie żądania
    print(f"\n===== NOWE ZAPYTANIE =====")
    print(f"Content-Type: {request.headers.get('Content-Type', 'brak')}")
    print(f"Długość danych: {request.content_length} bajtów")
    print(f"Surowe dane: {request.data.decode('utf-8', errors='replace')}")

    # Sprawdzenie Content-Type
    if not request.is_json:
        error_msg = "Oczekiwano danych JSON. Użyj nagłówka 'Content-Type: application/json'"
        print(f"⚠️ Błąd: {error_msg}")
        return jsonify({"error": error_msg}), 400

    # Obsługa błędów parsowania JSON
    try:
        data = request.get_json(force=False)
    except Exception as e:
        error_msg = f"Błąd parsowania JSON: {str(e)}"
        print(f"⚠️ {error_msg}")
        print(f"Stacktrace: {traceback.format_exc()}")
        return jsonify({"error": error_msg}), 400

    # Sprawdzenie struktury JSON
    if not isinstance(data, dict):
        error_msg = f"Oczekiwano obiektu JSON, otrzymano: {type(data).__name__}"
        print(f"⚠️ {error_msg}")
        return jsonify({"error": error_msg}), 400

    if 'prompt' not in data:
        error_msg = "Brak parametru 'prompt' w danych JSON"
        print(f"⚠️ {error_msg}")
        return jsonify({"error": error_msg}), 400

    prompt = data['prompt']
    temperature = data.get('temperature', 0.7)
    max_tokens = data.get('max_tokens', 1000)

    print(f"📤 Zapytanie: {prompt[:50]}...")

    # Wywołanie API Ollama
    response, error = call_ollama_api(prompt, temperature, max_tokens)

    if error:
        return jsonify({"error": error}), 500
    else:
        return jsonify({"response": response})


@app.route('/echo', methods=['POST'])
def echo():
    """Proste narzędzie do testowania działania serwera."""
    # Debugowanie żądania
    print(f"\n===== NOWE ZAPYTANIE ECHO =====")
    print(f"Content-Type: {request.headers.get('Content-Type', 'brak')}")
    print(f"Surowe dane: {request.data.decode('utf-8', errors='replace')}")

    if not request.is_json:
        error_msg = "Oczekiwano danych JSON. Użyj nagłówka 'Content-Type: application/json'"
        print(f"⚠️ Błąd: {error_msg}")
        return jsonify({"error": error_msg}), 400

    try:
        data = request.get_json(force=False)
    except Exception as e:
        error_msg = f"Błąd parsowania JSON: {str(e)}"
        print(f"⚠️ {error_msg}")
        return jsonify({"error": error_msg}), 400

    if not isinstance(data, dict):
        error_msg = f"Oczekiwano obiektu JSON, otrzymano: {type(data).__name__}"
        print(f"⚠️ {error_msg}")
        return jsonify({"error": error_msg}), 400

    if 'message' not in data:
        error_msg = "Brak parametru 'message' w danych JSON"
        print(f"⚠️ {error_msg}")
        return jsonify({"error": error_msg}), 400

    message = data['message']
    print(f"📤 Echo: {message}")

    return jsonify({"response": f"Otrzymano: {message}"})


if __name__ == "__main__":
    print("🚀 Uruchamianie super prostego serwera TinyLLM (z poprawioną integracją Ollama)...")

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
    print("\n📝 Przykłady użycia (zwróć uwagę na format JSON - musi być w jednej linii):")
    print(
        f"curl -X POST -H \"Content-Type: application/json\" -d '{{\"message\":\"Test\"}}' http://localhost:{PORT}/echo")
    print(
        f"curl -X POST -H \"Content-Type: application/json\" -d '{{\"prompt\":\"Co to jest Python?\"}}' http://localhost:{PORT}/ask")

    # Uruchomienie serwera na wszystkich interfejsach z lepszym logowaniem
    app.run(host='0.0.0.0', port=PORT, debug=True)