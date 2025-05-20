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
