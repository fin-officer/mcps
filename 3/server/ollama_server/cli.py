"""
Interfejs wiersza poleceń dla serwera Ollama.

Umożliwia uruchamianie i konfigurację serwera z wiersza poleceń.
"""

import os
import sys
import click
from .config import load_config, update_env_var, DEFAULT_CONFIG
from .models import OllamaClient, MODEL_INFO
from .server import run_server
import logging

# Konfiguracja logowania
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("ollama_server.cli")


@click.group()
def cli():
    """Uniwersalny serwer dla modeli Ollama."""
    pass


@cli.command()
@click.option("--host", default="0.0.0.0", help="Adres, na którym nasłuchuje serwer")
@click.option("--port", default=None, type=int, help="Port serwera (domyślnie: z konfiguracji)")
@click.option("--debug/--no-debug", default=None, help="Tryb debug")
@click.option("--config", default=None, help="Ścieżka do pliku konfiguracyjnego")
def run(host, port, debug, config):
    """Uruchamia serwer Ollama."""
    run_server(host=host, port=port, debug=debug, config_path=config)


@cli.command()
@click.option("--config", default=None, help="Ścieżka do pliku konfiguracyjnego")
def info(config):
    """Wyświetla informacje o konfiguracji."""
    cfg = load_config(config)

    click.echo("Konfiguracja Ollama Server:")
    click.echo(f"  Model: {cfg['MODEL_NAME']}")
    click.echo(f"  URL Ollama: {cfg['OLLAMA_URL']}")
    click.echo(f"  Port serwera: {cfg['SERVER_PORT']}")
    click.echo(f"  Temperatura: {cfg['TEMPERATURE']}")
    click.echo(f"  Max tokenów: {cfg['MAX_TOKENS']}")
    click.echo(f"  Debug: {cfg['DEBUG']}")

    # Sprawdź dostępność Ollama
    client = OllamaClient(cfg["OLLAMA_URL"])
    if client.check_availability():
        click.echo("\nStatus Ollama: ✅ Działa")

        # Pobierz listę modeli
        models = client.list_models()
        if models:
            click.echo("\nDostępne modele:")
            for i, model in enumerate(models, 1):
                name = model["name"]
                size = model.get("size", "?")
                current = " (aktualny)" if name == cfg["MODEL_NAME"] else ""
                click.echo(f"  {i}. {name} - {size} MB{current}")
        else:
            click.echo("\nBrak dostępnych modeli")

        # Sprawdź aktualny model
        model_name = cfg["MODEL_NAME"].split(":")[0]
        if client.check_model_availability(model_name):
            click.echo(f"\nAktualny model ({model_name}): ✅ Dostępny")
        else:
            click.echo(f"\nAktualny model ({model_name}): ❌ Niedostępny")
            click.echo(f"Możesz pobrać model komendą: ollama pull {model_name}")
    else:
        click.echo("\nStatus Ollama: ❌ Niedostępny")
        click.echo("Uruchom Ollama komendą: ollama serve")


@cli.command()
@click.option("--config", default=None, help="Ścieżka do pliku konfiguracyjnego")
def models(config):
    """Wyświetla informacje o dostępnych modelach."""
    cfg = load_config(config)

    # Sprawdź dostępność Ollama
    client = OllamaClient(cfg["OLLAMA_URL"])
    if client.check_availability():
        # Pobierz listę modeli
        models = client.list_models()
        if models:
            click.echo("Dostępne modele:")
            for i, model in enumerate(models, 1):
                name = model["name"]
                size = model.get("size", "?")
                current = " (aktualny)" if name == cfg["MODEL_NAME"] else ""
                click.echo(f"  {i}. {name} - {size} MB{current}")
        else:
            click.echo("Brak dostępnych modeli")
    else:
        click.echo("Status Ollama: ❌ Niedostępny")
        click.echo("Uruchom Ollama komendą: ollama serve")

    # Wyświetl znane modele
    click.echo("\nZnane modele, które można pobrać:")
    for i, (name, info) in enumerate(MODEL_INFO.items(), 1):
        click.echo(f"  {i}. {name} ({info['size']}): {info['description']}")


@cli.command()
@click.argument("model")
@click.option("--config", default=None, help="Ścieżka do pliku konfiguracyjnego")
def setup_model(model, config):
    """
    Konfiguruje i pobiera model Ollama.

    MODEL - nazwa modelu do skonfigurowania
    """
    cfg = load_config(config)

    # Pobierz informacje o modelu
    base_model = model.split(":")[0]
    model_info = MODEL_INFO.get(base_model, {"size": "?", "description": "Brak informacji"})

    click.echo(f"Konfiguracja modelu: {model}")
    click.echo(f"  Rozmiar: {model_info['size']}")
    click.echo(f"  Opis: {model_info['description']}")

    # Sprawdź dostępność Ollama
    client = OllamaClient(cfg["OLLAMA_URL"])
    if not client.check_availability():
        click.echo("\nStatus Ollama: ❌ Niedostępny")
        click.echo("Uruchom Ollama komendą: ollama serve")
        return

    # Sprawdź czy model jest już dostępny
    if client.check_model_availability(base_model):
        click.echo(f"\nModel {base_model}: ✅ Już dostępny")
    else:
        click.echo(f"\nModel {base_model}: ❌ Niedostępny")
        if click.confirm("Czy chcesz pobrać model?", default=True):
            click.echo(f"Pobieranie modelu {model}...")
            if client.pull_model(model):
                click.echo(f"✅ Model {model} został pobrany pomyślnie")
            else:
                click.echo(f"❌ Nie udało się pobrać modelu {model}")
                return

    # Aktualizuj konfigurację
    update_env_var("MODEL_NAME", model, config)
    click.echo(f"\n✅ Skonfigurowano {model} jako domyślny model")


@cli.command()
@click.option("--model", default=DEFAULT_CONFIG["MODEL_NAME"], help="Nazwa modelu")
@click.option("--port", default=DEFAULT_CONFIG["SERVER_PORT"], help="Port serwera")
@click.option("--temp", default=DEFAULT_CONFIG["TEMPERATURE"], help="Temperatura generowania")
@click.option("--tokens", default=DEFAULT_CONFIG["MAX_TOKENS"], help="Maksymalna liczba tokenów")
@click.option("--config", default=None, help="Ścieżka do pliku konfiguracyjnego")
def config(model, port, temp, tokens, config):
    """Konfiguruje ustawienia serwera."""
    # Aktualizuj zmienne
    update_env_var("MODEL_NAME", model, config)
    update_env_var("SERVER_PORT", port, config)
    update_env_var("TEMPERATURE", temp, config)
    update_env_var("MAX_TOKENS", tokens, config)

    click.echo("✅ Konfiguracja została zaktualizowana")
    click.echo(f"  MODEL_NAME: {model}")
    click.echo(f"  SERVER_PORT: {port}")
    click.echo(f"  TEMPERATURE: {temp}")
    click.echo(f"  MAX_TOKENS: {tokens}")


@cli.command()
@click.argument("prompt")
@click.option("--model", default=None, help="Nazwa modelu (domyślnie: z konfiguracji)")
@click.option("--temp", default=None, help="Temperatura generowania")
@click.option("--tokens", default=None, help="Maksymalna liczba tokenów")
@click.option("--config", default=None, help="Ścieżka do pliku konfiguracyjnego")
def ask(prompt, model, temp, tokens, config):
    """
    Zadaje pytanie modelowi Ollama.

    PROMPT - pytanie do modelu
    """
    cfg = load_config(config)

    # Użyj wartości z parametrów lub z konfiguracji
    model = model or cfg["MODEL_NAME"]
    temp = float(temp) if temp is not None else cfg["TEMPERATURE"]
    tokens = int(tokens) if tokens is not None else cfg["MAX_TOKENS"]

    # Sprawdź dostępność Ollama
    client = OllamaClient(cfg["OLLAMA_URL"])
    if not client.check_availability():
        click.echo("Status Ollama: ❌ Niedostępny")
        click.echo("Uruchom Ollama komendą: ollama serve")
        return

    # Sprawdź dostępność modelu
    base_model = model.split(":")[0]
    if not client.check_model_availability(base_model):
        click.echo(f"Model {model}: ❌ Niedostępny")
        if click.confirm("Czy chcesz pobrać model?", default=True):
            click.echo(f"Pobieranie modelu {model}...")
            if client.pull_model(model):
                click.echo(f"✅ Model {model} został pobrany pomyślnie")
            else:
                click.echo(f"❌ Nie udało się pobrać modelu {model}")
                return
        else:
            return

    # Zadaj pytanie
    click.echo(f"Pytanie: {prompt}")
    click.echo("\nGenerowanie odpowiedzi...\n")

    response = client.generate(
        model_name=model,
        prompt=prompt,
        temperature=temp,
        max_tokens=tokens
    )

    click.echo(f"Odpowiedź:\n\n{response}")


def main():
    """Główna funkcja CLI."""
    try:
        cli()
    except Exception as e:
        logger.error(f"Błąd: {str(e)}")
        click.echo(f"Wystąpił błąd: {str(e)}", err=True)
        sys.exit(1)


if __name__ == "__main__":
    main()