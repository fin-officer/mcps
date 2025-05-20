#!/usr/bin/env python3
"""
Moduł do ładowania konfiguracji z pliku .env dla serwera Ollama
"""

import os
import sys
import re
from dotenv import load_dotenv


def load_env_config(env_file=".env"):
    """
    Ładuje konfigurację z pliku .env lub tworzy plik z domyślnymi wartościami.

    Args:
        env_file: ścieżka do pliku .env

    Returns:
        dict: słownik z parametrami konfiguracyjnymi
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
    if not os.path.exists(env_file):
        print(f"Plik {env_file} nie istnieje. Tworzenie z domyślnymi wartościami...")
        create_env_file(env_file, config)

    # Ładowanie zmiennych z pliku .env
    load_dotenv(env_file)

    # Aktualizacja konfiguracji ze zmiennych środowiskowych
    for key in config:
        env_value = os.getenv(key)
        if env_value is not None:
            # Konwersja na odpowiedni typ
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
                    print(f"Ostrzeżenie: {key}={env_value} nie jest liczbą. Używanie wartości domyślnej: {config[key]}")
            else:
                # Usunięcie cudzysłowów, jeśli są
                value = env_value.strip('"\'')
                config[key] = value

    return config


def create_env_file(env_file, config):
    """
    Tworzy plik .env z domyślnymi wartościami.

    Args:
        env_file: ścieżka do pliku .env
        config: słownik z parametrami konfiguracyjnymi
    """
    with open(env_file, 'w') as f:
        f.write("# Konfiguracja modelu Ollama\n")
        f.write(f'MODEL_NAME="{config["MODEL_NAME"]}"\n\n')

        f.write("# Konfiguracja serwera\n")
        f.write(f'OLLAMA_URL="{config["OLLAMA_URL"]}"\n')
        f.write(f'SERVER_PORT={config["SERVER_PORT"]}\n\n')

        f.write("# Parametry generowania\n")
        f.write(f'TEMPERATURE={config["TEMPERATURE"]}\n')
        f.write(f'MAX_TOKENS={config["MAX_TOKENS"]}\n')


def update_env_value(env_file, key, value):
    """
    Aktualizuje wartość w pliku .env.

    Args:
        env_file: ścieżka do pliku .env
        key: klucz do zaktualizowania
        value: nowa wartość

    Returns:
        bool: True jeśli aktualizacja się powiodła, False w przeciwnym razie
    """
    if not os.path.exists(env_file):
        print(f"Plik {env_file} nie istnieje.")
        return False

    # Odczytanie zawartości pliku
    with open(env_file, 'r') as f:
        lines = f.readlines()

    # Sprawdzenie typu wartości i formatowanie
    if isinstance(value, str):
        value = f'"{value}"'

    # Flaga czy klucz został znaleziony
    found = False

    # Aktualizacja wartości
    for i, line in enumerate(lines):
        if re.match(f'^{key}=', line):
            lines[i] = f'{key}={value}\n'
            found = True
            break

    # Jeśli klucz nie został znaleziony, dodaj go na końcu
    if not found:
        lines.append(f'{key}={value}\n')

    # Zapisanie zaktualizowanej zawartości
    with open(env_file, 'w') as f:
        f.writelines(lines)

    return True


def update_server_config(server_file, model_name):
    """
    Aktualizuje konfigurację modelu w pliku serwera.

    Args:
        server_file: ścieżka do pliku serwera
        model_name: nazwa modelu

    Returns:
        bool: True jeśli aktualizacja się powiodła, False w przeciwnym razie
    """
    if not os.path.exists(server_file):
        print(f"Plik {server_file} nie istnieje.")
        return False

    # Odczytanie zawartości pliku
    with open(server_file, 'r') as f:
        content = f.read()

    # Aktualizacja MODEL_NAME w pliku serwera
    pattern = r'MODEL_NAME = "[^"]*"'
    replacement = f'MODEL_NAME = "{model_name}"'
    updated_content = re.sub(pattern, replacement, content)

    # Sprawdzenie czy coś się zmieniło
    if updated_content == content:
        print(f"Ostrzeżenie: Nie znaleziono MODEL_NAME w pliku {server_file}.")
        return False

    # Zapisanie zaktualizowanej zawartości
    with open(server_file, 'w') as f:
        f.write(updated_content)

    return True


# Przykład użycia
if __name__ == "__main__":
    # Ładowanie konfiguracji
    config = load_env_config()

    # Wyświetlenie konfiguracji
    print("Konfiguracja z pliku .env:")
    for key, value in config.items():
        print(f"{key}: {value}")

    # Przykład aktualizacji modelu, jeśli podano jako argument
    if len(sys.argv) > 1:
        model_name = sys.argv[1]
        print(f"\nAktualizacja modelu na: {model_name}")

        # Aktualizacja w pliku .env
        update_env_value("../2/.env", "MODEL_NAME", model_name)

        # Aktualizacja w pliku serwera
        server_files = ["server4.py", "super_simple_server.py"]
        for file in server_files:
            if os.path.exists(file):
                update_server_config(file, model_name)