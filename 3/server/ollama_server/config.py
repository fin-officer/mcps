"""
Moduł konfiguracyjny dla Ollama Server.

Obsługuje ładowanie zmiennych środowiskowych z pliku .env oraz
dostarczenie domyślnych ustawień.
"""

import os
import logging
from pathlib import Path
from dotenv import load_dotenv, find_dotenv, set_key

# Konfiguracja logowania
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("ollama_server.config")

# Domyślne wartości konfiguracyjne
DEFAULT_CONFIG = {
    "MODEL_NAME": "tinyllama:latest",
    "OLLAMA_URL": "http://localhost:11434",
    "SERVER_PORT": 5001,
    "TEMPERATURE": 0.7,
    "MAX_TOKENS": 1000,
    "DEBUG": False,
}


def find_or_create_env(env_path=None):
    """Znajdź istniejący plik .env lub utwórz nowy z domyślnymi wartościami."""
    if env_path is None:
        # Sprawdź bieżący katalog, katalog domowy użytkownika, lub katalog aplikacji
        env_file = find_dotenv(usecwd=True)
        if not env_file:
            # Utwórz plik .env w bieżącym katalogu
            env_file = os.path.join(os.getcwd(), ".env")
            create_default_env(env_file)
    else:
        env_file = env_path
        if not os.path.exists(env_file):
            create_default_env(env_file)

    return env_file


def create_default_env(env_file):
    """Utwórz nowy plik .env z domyślnymi ustawieniami."""
    logger.info(f"Tworzenie nowego pliku .env w: {env_file}")

    # Upewnij się, że katalog istnieje
    os.makedirs(os.path.dirname(os.path.abspath(env_file)), exist_ok=True)

    # Utwórz plik z domyślnymi wartościami
    with open(env_file, "w") as f:
        f.write("# Konfiguracja Ollama Server\n\n")
        f.write("# Model Ollama\n")
        f.write(f"MODEL_NAME=\"{DEFAULT_CONFIG['MODEL_NAME']}\"\n\n")
        f.write("# Konfiguracja serwera\n")
        f.write(f"OLLAMA_URL=\"{DEFAULT_CONFIG['OLLAMA_URL']}\"\n")
        f.write(f"SERVER_PORT={DEFAULT_CONFIG['SERVER_PORT']}\n\n")
        f.write("# Parametry generowania\n")
        f.write(f"TEMPERATURE={DEFAULT_CONFIG['TEMPERATURE']}\n")
        f.write(f"MAX_TOKENS={DEFAULT_CONFIG['MAX_TOKENS']}\n")
        f.write(f"DEBUG={str(DEFAULT_CONFIG['DEBUG']).lower()}\n")


def update_env_var(key, value, env_file=None):
    """Aktualizuje zmienną w pliku .env."""
    if env_file is None:
        env_file = find_or_create_env()

    logger.info(f"Aktualizacja zmiennej {key}={value} w pliku {env_file}")
    set_key(env_file, key, str(value))
    # Załaduj zaktualizowane zmienne
    load_dotenv(env_file, override=True)


def load_config(env_path=None):
    """Ładuje konfigurację z pliku .env."""
    env_file = find_or_create_env(env_path)
    logger.info(f"Ładowanie konfiguracji z: {env_file}")
    load_dotenv(env_file, override=True)

    config = {
        "MODEL_NAME": os.getenv("MODEL_NAME", DEFAULT_CONFIG["MODEL_NAME"]),
        "OLLAMA_URL": os.getenv("OLLAMA_URL", DEFAULT_CONFIG["OLLAMA_URL"]),
        "SERVER_PORT": int(os.getenv("SERVER_PORT", DEFAULT_CONFIG["SERVER_PORT"])),
        "TEMPERATURE": float(os.getenv("TEMPERATURE", DEFAULT_CONFIG["TEMPERATURE"])),
        "MAX_TOKENS": int(os.getenv("MAX_TOKENS", DEFAULT_CONFIG["MAX_TOKENS"])),
        "DEBUG": os.getenv("DEBUG", str(DEFAULT_CONFIG["DEBUG"])).lower() in ("true", "1", "t"),
    }

    return config


if __name__ == "__main__":
    # Jeśli uruchomiony bezpośrednio, wyświetl bieżącą konfigurację
    config = load_config()
    print("Bieżąca konfiguracja:")
    for key, value in config.items():
        print(f"  - {key}: {value}")