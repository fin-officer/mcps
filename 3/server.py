#!/usr/bin/env python3
"""
Zaawansowany serwer Flask dla Ollama z obsługą różnych modeli i konfiguracją z .env
"""

import os
import sys
import json
import traceback
import requests
from flask import Flask, request, jsonify, render_template_string

# Sprawdzenie czy potrzebne moduły są zainstalowane
try:
    from dotenv import load_dotenv
except ImportError:
    print("Błąd: Brak wymaganego pakietu 'python-dotenv'")
    print("Instalacja: pip install python-dotenv")
    sys.exit(1)

# Sprawdzenie czy plik env_loader.py istnieje
if os.path.exists("env_loader.py"):
    try:
        from env_loader import load_env_config
    except ImportError:
        print("Błąd: Nie można zaimportować modułu env_loader.py")
        sys.exit(1)
else:
    # Funkcja do ładowania konfiguracji jeśli nie ma env_loader.py
    def load_env_config(env_file=".env"):
        """
        Prosta wersja funkcji ładującej konfigurację z pliku .env
        """
        # Domyślne wartości
        config = {
            "MODEL_NAME": "tinyllama:latest",
            "OLLAMA_URL": "http://localhost:11434",
            "SERVER_PORT": 5001,
            "TEMPERATURE": 0.7,
            "MAX_TOKENS": 1000
        }

        # Sprawdzenie czy plik .env istnieje
        if os.path.exists(env_file):
            # Ładowanie zmiennych z pliku .env
            load_dotenv(env_file)

            # Aktualizacja konfiguracji ze zmiennych środowiskowych
            for key in config:
                env_value = os.getenv(key)
                if env_value is not None:
                    if key in ["SERVER_PORT", "MAX_TOKENS"]:
                        try:
                            config[key] = int(env_value)
                        except ValueError:
                            print(
                                f"Ostrzeżenie: {key}={env_value} nie jest liczbą całkowitą. Używanie wartości domyślnej: {config[key]}")
                    elif key in ["TEMPERATURE"]:
                        try:
                            config[key] = float(env_value)
                        except ValueError:
                            print(
                                f"Ostrzeżenie: {key}={env_value} nie jest liczbą. Używanie wartości domyślnej: {config[key]}")
                    else:
                        # Usunięcie cudzysłowów, jeśli są
                        value = env_value.strip('"\'')
                        config[key] = value
        else:
            print(f"Plik {env_file} nie istnieje. Używanie wartości domyślnych.")

            # Tworzenie pliku .env z domyślnymi wartościami
            with open(env_file, 'w') as f:
                f.write("# Konfiguracja modelu Ollama\n")
                f.write(f'MODEL_NAME="{config["MODEL_NAME"]}"\n\n')

                f.write("# Konfiguracja serwera\n")
                f.write(f'OLLAMA_URL="{config["OLLAMA_URL"]}"\n')
                f.write(f'SERVER_PORT={config["SERVER_PORT"]}\n\n')

                f.write("# Parametry generowania\n")
                f.write(f'TEMPERATURE={config["TEMPERATURE"]}\n')
                f.write(f'MAX_TOKENS={config["MAX_TOKENS"]}\n')

        return config

# Ładowanie konfiguracji z pliku .env
try:
    config = load_env_config()
except Exception as e:
    print(f"Błąd podczas ładowania konfiguracji: {str(e)}")
    # Domyślne wartości w przypadku błędu
    config = {
        "MODEL_NAME": "tinyllama:latest",
        "OLLAMA_URL": "http://localhost:11434",
        "SERVER_PORT": 5001,
        "TEMPERATURE": 0.7,
        "MAX_TOKENS": 1000
    }

# Konfiguracja z pliku .env
OLLAMA_URL = config["OLLAMA_URL"]
MODEL_NAME = config["MODEL_NAME"]
SERVER_PORT = config["SERVER_PORT"]
DEFAULT_TEMPERATURE = float(config["TEMPERATURE"])
DEFAULT_MAX_TOKENS = int(config["MAX_TOKENS"])

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

        # Sprawdzenie pełnej nazwy modelu
        for model in models:
            if model["name"] == MODEL_NAME:
                model_exists = True
                break

        # Sprawdzenie nazwy modelu bez wersji (np. tinyllama zamiast tinyllama:latest)
        if not model_exists and ":" in MODEL_NAME:
            model_base = MODEL_NAME.split(":")[0]
            for model in models:
                if model["name"].startswith(model_base):
                    print(f"✓ Znaleziono podobny model: {model['name']} (zamiast {MODEL_NAME})")
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
    """Strona główna z interfejsem użytkownika."""
    html_template = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Serwer Ollama</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { 
                font-family: Arial, sans-serif; 
                max-width: 800px; 
                margin: 0 auto; 
                padding: 20px;
                line-height: 1.6;
            }
            h1, h2 { color: #333; }
            h1 { border-bottom: 2px solid #eee; padding-bottom: 10px; }
            .card {
                background: #f9f9f9;
                border-radius: 8px;
                padding: 15px;
                margin-bottom: 20px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            pre { 
                background: #f4f4f4; 
                padding: 10px; 
                border-radius: 5px; 
                overflow-x: auto;
            }
            .response-area {
                border: 1px solid #ddd;
                border-radius: 5px;
                padding: 15px;
                min-height: 100px;
                margin-top: 10px;
                background: #fff;
            }
            .btn {
                background: #4CAF50;
                color: white;
                border: none;
                padding: 10px 15px;
                border-radius: 4px;
                cursor: pointer;
                font-size: 16px;
            }
            .btn:hover { background: #45a049; }
            textarea, input, select {
                width: 100%;
                padding: 8px;
                margin: 5px 0 15px 0;
                border: 1px solid #ddd;
                border-radius: 4px;
                box-sizing: border-box;
            }
            .parameter-row {
                display: flex;
                justify-content: space-between;
                gap: 10px;
            }
            .parameter-row > div {
                flex: 1;
            }
            .footer {
                text-align: center;
                margin-top: 30px;
                padding-top: 10px;
                border-top: 1px solid #eee;
                font-size: 14px;
                color: #666;
            }
            @media (max-width: 600px) {
                .parameter-row {
                    flex-direction: column;
                }
            }
        </style>
    </head>
    <body>
        <h1>Serwer Ollama - Interfejs API</h1>

        <div class="card">
            <h2>Status</h2>
            <p><strong>Model:</strong> {{ model_name }}</p>
            <p><strong>URL Ollama:</strong> {{ ollama_url }}</p>
            <p><strong>Port serwera:</strong> {{ server_port }}</p>
        </div>

        <div class="card">
            <h2>Testuj API</h2>
            <form id="testForm">
                <div>
                    <label for="prompt"><strong>Zapytanie:</strong></label>
                    <textarea id="prompt" name="prompt" rows="4" placeholder="Wpisz swoje zapytanie tutaj..."></textarea>
                </div>

                <div class="parameter-row">
                    <div>
                        <label for="temperature"><strong>Temperatura:</strong></label>
                        <input type="number" id="temperature" name="temperature" min="0" max="2" step="0.1" value="{{ default_temperature }}">
                    </div>
                    <div>
                        <label for="max_tokens"><strong>Maksymalna długość:</strong></label>
                        <input type="number" id="max_tokens" name="max_tokens" min="10" max="4096" step="10" value="{{ default_max_tokens }}">
                    </div>
                </div>

                <button type="submit" class="btn">Wyślij zapytanie</button>
            </form>

            <h3>Odpowiedź:</h3>
            <div id="response" class="response-area">
                <p><em>Tutaj pojawi się odpowiedź...</em></p>
            </div>
        </div>

        <div class="card">
            <h2>API Endpoints</h2>

            <h3>POST /ask</h3>
            <p>Zadaj pytanie do modelu Ollama.</p>
            <pre>curl -X POST -H "Content-Type: application/json" \\
     -d '{"prompt":"Co to jest Python?"}' \\
     http://localhost:{{ server_port }}/ask</pre>

            <h3>GET /models</h3>
            <p>Pobierz listę dostępnych modeli.</p>
            <pre>curl http://localhost:{{ server_port }}/models</pre>

            <h3>POST /echo</h3>
            <p>Proste narzędzie do testów - odbija wiadomość.</p>
            <pre>curl -X POST -H "Content-Type: application/json" \\
     -d '{"message":"Test"}' \\
     http://localhost:{{ server_port }}/echo</pre>
        </div>

        <div class="footer">
            Serwer Ollama z obsługą modeli LLM | Port: {{ server_port }}
        </div>

        <script>
            document.getElementById('testForm').addEventListener('submit', function(e) {
                e.preventDefault();

                const prompt = document.getElementById('prompt').value;
                const temperature = document.getElementById('temperature').value;
                const max_tokens = document.getElementById('max_tokens').value;

                if (!prompt) {
                    alert('Proszę wpisać zapytanie');
                    return;
                }

                const responseArea = document.getElementById('response');
                responseArea.innerHTML = '<p><em>Ładowanie odpowiedzi...</em></p>';

                fetch('/ask', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        prompt: prompt,
                        temperature: parseFloat(temperature),
                        max_tokens: parseInt(max_tokens)
                    })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.error) {
                        responseArea.innerHTML = `<p style="color: red"><strong>Błąd:</strong> ${data.error}</p>`;
                    } else {
                        responseArea.innerHTML = `<p>${data.response.replace(/\\n/g, '<br>')}</p>`;
                    }
                })
                .catch(error => {
                    responseArea.innerHTML = `<p style="color: red"><strong>Błąd:</strong> ${error}</p>`;
                });
            });
        </script>
    </body>
    </html>
    """
    return render_template_string(
        html_template,
        model_name=MODEL_NAME,
        ollama_url=OLLAMA_URL,
        server_port=SERVER_PORT,
        default_temperature=DEFAULT_TEMPERATURE,
        default_max_tokens=DEFAULT_MAX_TOKENS
    )


def call_ollama_api(prompt, temperature=None, max_tokens=None):
    """
    Bezpieczne wywołanie API Ollama z obsługą błędów.

    Args:
        prompt: Zapytanie do modelu
        temperature: Temperatura generowania (opcjonalnie)
        max_tokens: Maksymalna liczba tokenów w odpowiedzi (opcjonalnie)

    Returns:
        str: Odpowiedź od modelu lub komunikat o błędzie
    """
    try:
        # Użycie domyślnych wartości, jeśli nie podano
        if temperature is None:
            temperature = DEFAULT_TEMPERATURE
        if max_tokens is None:
            max_tokens = DEFAULT_MAX_TOKENS

        # Konwersja na odpowiednie typy, jeśli to potrzebne
        try:
            temperature = float(temperature)
        except (ValueError, TypeError):
            print(f"⚠️ Nieprawidłowa wartość temperature: {temperature}, używam domyślnej: {DEFAULT_TEMPERATURE}")
            temperature = DEFAULT_TEMPERATURE

        try:
            max_tokens = int(max_tokens)
        except (ValueError, TypeError):
            print(f"⚠️ Nieprawidłowa wartość max_tokens: {max_tokens}, używam domyślnej: {DEFAULT_MAX_TOKENS}")
            max_tokens = DEFAULT_MAX_TOKENS

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
            # Wydobycie tekstu odpowiedzi
            response_text = response.text.strip()

            # Próba parsowania jako pojedynczy JSON
            try:
                result = json.loads(response_text)
                ollama_response = result.get("response", "")
                print(f"📥 Odpowiedź Ollama (długość: {len(ollama_response)} znaków)")
                return ollama_response, None
            except json.JSONDecodeError:
                # Jeśli to nie jest pojedynczy JSON, próbujemy parsować linia po linii
                print(f"⚠️ Odpowiedź nie jest pojedynczym obiektem JSON. Próbuję parsować linia po linii...")

                lines = response_text.split("\n")
                if len(lines) > 0:
                    try:
                        # Próba parsowania pierwszej linii
                        first_line_result = json.loads(lines[0])
                        ollama_response = first_line_result.get("response", "")
                        print(f"📥 Odpowiedź z pierwszej linii (długość: {len(ollama_response)} znaków)")
                        return ollama_response, None
                    except json.JSONDecodeError:
                        # Jeśli nadal się nie udaje, próbujemy alternatywnego podejścia
                        pass

                # Ręczne parsowanie dla strumieniowej odpowiedzi
                text_content = ""
                for line in lines:
                    if not line.strip():
                        continue
                    try:
                        chunk = json.loads(line)
                        if "response" in chunk:
                            text_content += chunk["response"]
                    except json.JSONDecodeError:
                        continue

                if text_content:
                    print(f"📥 Odpowiedź wyodrębniona ręcznie (długość: {len(text_content)} znaków)")
                    return text_content, None

                # Jeśli wszystko zawiedzie, zwracamy surowy tekst odpowiedzi
                print(f"⚠️ Nie udało się sparsować odpowiedzi jako JSON. Zwracam surowy tekst.")
                return response_text, None
        except Exception as e:
            error_msg = f"Błąd przetwarzania odpowiedzi: {str(e)}"
            print(f"⚠️ {error_msg}")
            return None, error_msg
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
def ask():
    """Zadaj pytanie do modelu Ollama."""
    # Debugowanie żądania
    print(f"\n===== NOWE ZAPYTANIE =====")
    print(f"Content-Type: {request.headers.get('Content-Type', 'brak')}")
    print(f"Długość danych: {request.content_length} bajtów")

    # Zabezpieczenie przed brakiem danych
    if not request.data:
        error_msg = "Brak danych w żądaniu"
        print(f"⚠️ Błąd: {error_msg}")
        return jsonify({"error": error_msg}), 400

    try:
        # Próba zdekodowania danych jako tekst
        raw_data = request.data.decode('utf-8', errors='replace')
        print(f"Surowe dane: {raw_data}")
    except Exception as e:
        print(f"⚠️ Błąd podczas dekodowania danych: {str(e)}")

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

    # Sprawdzenie czy dane są słownikiem
    if data is None:
        error_msg = "Brak danych JSON w żądaniu"
        print(f"⚠️ {error_msg}")
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
    temperature = data.get('temperature', DEFAULT_TEMPERATURE)
    max_tokens = data.get('max_tokens', DEFAULT_MAX_TOKENS)

    print(f"📤 Zapytanie: {prompt[:50]}...")

    # Wywołanie API Ollama
    response, error = call_ollama_api(prompt, temperature, max_tokens)

    if error:
        return jsonify({"error": error}), 500
    elif response:
        return jsonify({"response": response})
    else:
        return jsonify({"error": "Pusta odpowiedź od serwera Ollama"}), 500


@app.route('/models', methods=['GET'])
def get_models():
    """Pobierz listę dostępnych modeli Ollama."""
    try:
        response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)

        if response.status_code != 200:
            return jsonify({"error": f"Błąd odpowiedzi z Ollama: {response.status_code}"}), 500

        # Pobranie listy modeli z odpowiedzi
        models = response.json().get("models", [])

        # Dodanie informacji o aktualnie używanym modelu
        for model in models:
            model["current"] = (model["name"] == MODEL_NAME)

        return jsonify({"models": models})
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "Nie można połączyć się z serwerem Ollama"}), 500
    except Exception as e:
        return jsonify({"error": f"Błąd podczas pobierania modeli: {str(e)}"}), 500


@app.route('/echo', methods=['POST'])
def echo():
    """Proste narzędzie do testowania działania serwera."""
    # Debugowanie żądania
    print(f"\n===== NOWE ZAPYTANIE ECHO =====")
    print(f"Content-Type: {request.headers.get('Content-Type', 'brak')}")

    # Zabezpieczenie przed brakiem danych
    if not request.data:
        error_msg = "Brak danych w żądaniu"
        print(f"⚠️ Błąd: {error_msg}")
        return jsonify({"error": error_msg}), 400

    try:
        # Próba zdekodowania danych jako tekst
        raw_data = request.data.decode('utf-8', errors='replace')
        print(f"Surowe dane: {raw_data}")
    except Exception as e:
        print(f"⚠️ Błąd podczas dekodowania danych: {str(e)}")

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

    # Sprawdzenie czy dane są słownikiem
    if data is None:
        error_msg = "Brak danych JSON w żądaniu"
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
    print("🚀 Uruchamianie zaawansowanego serwera Ollama...")

    # Wyświetlenie konfiguracji
    print(f"📄 Konfiguracja z pliku .env:")
    print(f"  - Model: {MODEL_NAME}")
    print(f"  - URL Ollama: {OLLAMA_URL}")
    print(f"  - Port serwera: {SERVER_PORT}")
    print(f"  - Temperatura: {DEFAULT_TEMPERATURE}")
    print(f"  - Max tokenów: {DEFAULT_MAX_TOKENS}")

    # Sprawdzenie dostępności Ollama przed uruchomieniem
    if not check_ollama_available():
        choice = input("Czy chcesz kontynuować mimo to? (t/n): ")
        if choice.lower() != 't':
            print("Zamykanie...")
            sys.exit(1)

    # Uruchomienie serwera
    print(f"🔌 Uruchamianie serwera na porcie {SERVER_PORT}...")
    print(f"ℹ️ Dostępne endpointy: /, /ask, /models, /echo")
    print(f"📝 Interfejs web: http://localhost:{SERVER_PORT}")

    try:
        # Próba uruchomienia serwera
        app.run(host='0.0.0.0', port=SERVER_PORT, debug=True)
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"⚠️ Błąd: Port {SERVER_PORT} jest już używany przez inną aplikację.")
            print(f"Zmień port w pliku .env lub zamknij aplikację używającą tego portu.")
        else:
            print(f"⚠️ Błąd: {str(e)}")
    except Exception as e:
        print(f"⚠️ Nieoczekiwany błąd: {str(e)}")
        traceback.print_exc()