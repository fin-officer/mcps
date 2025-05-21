"""
Moduł API dla serwera Ollama.

Definiuje endpoints REST API do interakcji z modelami Ollama.
"""

import logging
from flask import Blueprint, request, jsonify, current_app
from .models import OllamaClient, get_model_info

# Konfiguracja logowania
logger = logging.getLogger("ollama_server.api")

# Blueprint dla API
api_bp = Blueprint("api", __name__, url_prefix="/api")


@api_bp.route("/models", methods=["GET"])
def list_models():
    """
    Endpoint do listowania dostępnych modeli.

    Returns:
        JSON z listą dostępnych modeli.
    """
    client = OllamaClient(current_app.config["OLLAMA_URL"])
    models = client.list_models()

    # Dodaj informację o aktualnie używanym modelu
    current_model = current_app.config["MODEL_NAME"]
    for model in models:
        model["current"] = model["name"] == current_model

    return jsonify({"models": models})


@api_bp.route("/ask", methods=["POST"])
def ask():
    """
    Endpoint do zadawania pytań modelowi.

    Expects:
        JSON z kluczami:
        - prompt: Zapytanie do modelu
        - temperature (opcjonalnie): Temperatura generowania (0.0-1.0)
        - max_tokens (opcjonalnie): Maksymalna liczba tokenów w odpowiedzi

    Returns:
        JSON z odpowiedzią modelu.
    """
    data = request.json
    if not data or "prompt" not in data:
        return jsonify({"error": "Brak wymaganego pola 'prompt'"}), 400

    prompt = data["prompt"]
    temperature = data.get("temperature", current_app.config["TEMPERATURE"])
    max_tokens = data.get("max_tokens", current_app.config["MAX_TOKENS"])

    client = OllamaClient(current_app.config["OLLAMA_URL"])
    model_name = current_app.config["MODEL_NAME"]

    logger.info(f"Zapytanie do modelu {model_name}: {prompt[:50]}...")

    if not client.check_availability():
        return jsonify({"error": "Serwer Ollama jest niedostępny"}), 503

    if not client.check_model_availability(model_name.split(":")[0]):
        return jsonify({"error": f"Model {model_name} nie jest dostępny"}), 404

    response = client.generate(
        model_name=model_name,
        prompt=prompt,
        temperature=temperature,
        max_tokens=max_tokens
    )

    return jsonify({"response": response})


@api_bp.route("/echo", methods=["POST"])
def echo():
    """
    Prosty endpoint echo do testowania API.

    Expects:
        JSON z kluczem 'message'

    Returns:
        JSON z odbiciem wiadomości.
    """
    data = request.json
    if not data or "message" not in data:
        return jsonify({"error": "Brak wymaganego pola 'message'"}), 400

    message = data["message"]
    return jsonify({"response": f"Otrzymano: {message}"})


@api_bp.route("/model_info/<model_name>", methods=["GET"])
def model_info(model_name):
    """
    Endpoint do pobierania informacji o modelu.

    Args:
        model_name: Nazwa modelu.

    Returns:
        JSON z informacjami o modelu.
    """
    info = get_model_info(model_name)
    return jsonify({"name": model_name, **info})


@api_bp.route("/switch_model", methods=["POST"])
def switch_model():
    """
    Endpoint do przełączania używanego modelu.

    Expects:
        JSON z kluczem 'model_name'

    Returns:
        JSON z informacją o sukcesie lub błędzie.
    """
    data = request.json
    if not data or "model_name" not in data:
        return jsonify({"error": "Brak wymaganego pola 'model_name'"}), 400

    model_name = data["model_name"]
    client = OllamaClient(current_app.config["OLLAMA_URL"])

    # Sprawdź dostępność modelu
    if not client.check_model_availability(model_name.split(":")[0]):
        pull_model = data.get("pull_if_missing", False)

        if pull_model:
            logger.info(f"Model {model_name} nie jest dostępny, próba pobrania...")
            if not client.pull_model(model_name):
                return jsonify({"error": f"Nie można pobrać modelu {model_name}"}), 500
        else:
            return jsonify({"error": f"Model {model_name} nie jest dostępny"}), 404

    # Aktualizuj konfigurację
    logger.info(f"Przełączanie na model: {model_name}")
    current_app.config["MODEL_NAME"] = model_name

    # Aktualizuj zmienną w pamięci
    from . import config
    config.update_env_var("MODEL_NAME", model_name)

    return jsonify({"success": True, "model": model_name})