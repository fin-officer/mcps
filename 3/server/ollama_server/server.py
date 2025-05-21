"""
Główny moduł serwera Ollama.

Zawiera aplikację Flask, która obsługuje zapytania API i udostępnia interfejs web.
"""

import logging
import os
from flask import Flask, render_template, jsonify, request, redirect, url_for
from .config import load_config
from .models import OllamaClient
from .api import api_bp

# Konfiguracja logowania
logger = logging.getLogger("ollama_server")


def create_app(config_path=None):
    """
    Tworzy i konfiguruje aplikację Flask.

    Args:
        config_path: Ścieżka do pliku konfiguracyjnego .env

    Returns:
        Aplikacja Flask.
    """
    app = Flask(__name__, static_folder="web/static", template_folder="web/templates")

    # Ładowanie konfiguracji
    config = load_config(config_path)
    app.config.update(config)

    # Rejestracja blueprintów
    app.register_blueprint(api_bp)

    # Inicjalizacja klienta Ollama
    client = OllamaClient(app.config["OLLAMA_URL"])

    # Podstawowe trasy
    @app.route("/")
    def index():
        """Główna strona z interfejsem webowym."""
        # Sprawdź dostępność serwera Ollama
        ollama_available = client.check_availability()

        # Pobierz informacje o aktualnym modelu
        model_name = app.config["MODEL_NAME"]
        model_available = False

        if ollama_available:
            model_available = client.check_model_availability(model_name.split(":")[0])

        return render_template(
            "index.html",
            config=app.config,
            ollama_available=ollama_available,
            model_available=model_available
        )

    @app.route("/ask", methods=["POST"])
    def ask():
        """
        Endpoint do zadawania pytań z interfejsu webowego.
        Przekierowuje zapytanie do API.
        """
        prompt = request.form.get("prompt")
        temperature = float(request.form.get("temperature", app.config["TEMPERATURE"]))
        max_tokens = int(request.form.get("max_tokens", app.config["MAX_TOKENS"]))

        if not prompt:
            return jsonify({"error": "Brak wymaganego pola 'prompt'"}), 400

        from .api import ask as api_ask
        # Modyfikacja request.json dla API
        request.json = {
            "prompt": prompt,
            "temperature": temperature,
            "max_tokens": max_tokens
        }
        return api_ask()

    @app.route("/models")
    def models():
        """
        Endpoint do pobierania listy modeli.
        Przekierowuje zapytanie do API.
        """
        from .api import list_models as api_list_models
        return api_list_models()

    @app.route("/echo", methods=["POST"])
    def echo():
        """
        Endpoint echo do testowania serwera.
        Przekierowuje zapytanie do API.
        """
        message = request.form.get("message") or request.json.get("message")
        if not message:
            return jsonify({"error": "Brak wymaganego pola 'message'"}), 400

        # Modyfikacja request.json dla API
        request.json = {"message": message}
        from .api import echo as api_echo
        return api_echo()

    @app.route("/health")
    def health():
        """
        Endpoint sprawdzający zdrowie serwera.

        Returns:
            JSON ze statusem serwera i komponentów.
        """
        status = {
            "server": "ok",
            "ollama": "unknown"
        }

        # Sprawdź dostępność Ollama
        ollama_available = client.check_availability()
        status["ollama"] = "ok" if ollama_available else "unreachable"

        # Sprawdź dostępność modelu
        if ollama_available:
            model_name = app.config["MODEL_NAME"]
            model_available = client.check_model_availability(model_name.split(":")[0])
            status["model"] = "ok" if model_available else "unavailable"
            status["model_name"] = model_name

        # Ustaw kod statusu
        http_status = 200 if status["ollama"] == "ok" else 503

        return jsonify(status), http_status

    @app.route("/switch_model", methods=["POST"])
    def switch_model():
        """
        Endpoint do przełączania modelu.

        Returns:
            Przekierowanie do strony głównej lub odpowiedź JSON.
        """
        model_name = request.form.get("model_name")
        if not model_name:
            return jsonify({"error": "Brak wymaganego pola 'model_name'"}), 400

        # Użyj endpointu API do przełączenia modelu
        from .api import switch_model as api_switch_model
        request.json = {"model_name": model_name, "pull_if_missing": True}
        result = api_switch_model()

        # Sprawdź format odpowiedzi
        if request.headers.get("X-Requested-With") == "XMLHttpRequest":
            return result
        else:
            # Jeśli nie jest to żądanie AJAX, przekieruj na stronę główną
            return redirect(url_for("index"))

    # Obsługa błędów
    @app.errorhandler(404)
    def page_not_found(e):
        return render_template("error.html", error="Nie znaleziono strony"), 404

    @app.errorhandler(500)
    def internal_server_error(e):
        return render_template("error.html", error="Wewnętrzny błąd serwera"), 500

    return app


def run_server(host="0.0.0.0", port=None, debug=False, config_path=None):
    """
    Uruchamia serwer Flask.

    Args:
        host: Host nasłuchiwania
        port: Port nasłuchiwania (domyślnie: z konfiguracji)
        debug: Czy uruchomić w trybie debug
        config_path: Ścieżka do pliku konfiguracyjnego .env
    """
    app = create_app(config_path)

    if port is None:
        port = app.config["SERVER_PORT"]

    if debug is None:
        debug = app.config.get("DEBUG", False)

    # Wyświetl informacje o uruchomieniu
    model_name = app.config["MODEL_NAME"]
    ollama_url = app.config["OLLAMA_URL"]

    print(f"🚀 Uruchamianie serwera Ollama...")
    print(f"📄 Konfiguracja:")
    print(f"  - Model: {model_name}")
    print(f"  - URL Ollama: {ollama_url}")
    print(f"  - Port serwera: {port}")
    print(f"  - Temperatura: {app.config['TEMPERATURE']}")
    print(f"  - Max tokenów: {app.config['MAX_TOKENS']}")

    # Sprawdź dostępność Ollama
    client = OllamaClient(ollama_url)
    if client.check_availability():
        print(f"✅ Ollama działa poprawnie")

        # Sprawdź dostępność modelu
        if client.check_model_availability(model_name.split(":")[0]):
            print(f"✅ Model {model_name} jest dostępny")
        else:
            print(f"⚠️ Model {model_name} nie jest dostępny")
            print(f"   Możesz pobrać model komendą: ollama pull {model_name}")
    else:
        print(f"⚠️ Serwer Ollama nie jest dostępny")
        print(f"   Uruchom Ollama komendą: ollama serve")

    print(f"🔌 Uruchamianie serwera na porcie {port}...")
    print(f"ℹ️ Dostępne endpointy: /, /ask, /models, /echo")
    print(f"📝 Interfejs web: http://localhost:{port}")

    # Uruchom serwer
    app.run(host=host, port=port, debug=debug)


if __name__ == "__main__":
    run_server()