"""
Testy dla modułu konfiguracji.
"""

import os
import pytest
import tempfile
from unittest.mock import patch

from ollama_server.config import (
    load_config,
    update_env_var,
    find_or_create_env,
    create_default_env,
    DEFAULT_CONFIG
)


@pytest.fixture
def temp_env_file():
    """Tworzy tymczasowy plik .env do testów."""
    fd, path = tempfile.mkstemp()
    with os.fdopen(fd, 'w') as f:
        f.write("# Test file\n")
        f.write("MODEL_NAME=test-model:latest\n")
        f.write("SERVER_PORT=5000\n")
        f.write("TEMPERATURE=0.5\n")
        f.write("MAX_TOKENS=500\n")
        f.write("DEBUG=true\n")

    yield path

    # Usuń plik po teście
    os.unlink(path)


def test_load_config_default():
    """Test ładowania domyślnej konfiguracji."""
    with patch('ollama_server.config.find_or_create_env') as mock_find:
        # Przygotowanie mocka, zwraca nieistniejący plik
        mock_find.return_value = "/this/file/does/not/exist.env"

        # Ładowanie konfiguracji powinno użyć wartości domyślnych
        config = load_config()

        # Sprawdzenie wartości domyślnych
        assert config["MODEL_NAME"] == DEFAULT_CONFIG["MODEL_NAME"]
        assert config["SERVER_PORT"] == DEFAULT_CONFIG["SERVER_PORT"]
        assert config["TEMPERATURE"] == DEFAULT_CONFIG["TEMPERATURE"]
        assert config["MAX_TOKENS"] == DEFAULT_CONFIG["MAX_TOKENS"]
        assert config["DEBUG"] == DEFAULT_CONFIG["DEBUG"]


def test_load_config_from_file(temp_env_file):
    """Test ładowania konfiguracji z pliku."""
    # Ładowanie konfiguracji z pliku tymczasowego
    config = load_config(temp_env_file)

    # Sprawdzenie wartości z pliku
    assert config["MODEL_NAME"] == "test-model:latest"
    assert config["SERVER_PORT"] == 5000
    assert config["TEMPERATURE"] == 0.5
    assert config["MAX_TOKENS"] == 500
    assert config["DEBUG"] == True


def test_update_env_var(temp_env_file):
    """Test aktualizacji zmiennych w pliku .env."""
    # Aktualizacja zmiennej
    update_env_var("MODEL_NAME", "new-model:latest", temp_env_file)

    # Ładowanie zaktualizowanej konfiguracji
    config = load_config(temp_env_file)

    # Sprawdzenie czy wartość została zaktualizowana
    assert config["MODEL_NAME"] == "new-model:latest"

    # Sprawdzenie czy inne wartości pozostały niezmienione
    assert config["SERVER_PORT"] == 5000
    assert config["TEMPERATURE"] == 0.5


def test_update_env_var_add_new(temp_env_file):
    """Test dodania nowej zmiennej do pliku .env."""
    # Dodanie nowej zmiennej
    update_env_var("NEW_VARIABLE", "new-value", temp_env_file)

    # Odczytanie pliku
    with open(temp_env_file, 'r') as f:
        content = f.read()

    # Sprawdzenie czy zmienna została dodana
    assert "NEW_VARIABLE=new-value" in content


def test_find_or_create_env():
    """Test znajdowania lub tworzenia pliku .env."""
    with tempfile.TemporaryDirectory() as temp_dir:
        # Ścieżka do pliku .env w katalogu tymczasowym
        env_path = os.path.join(temp_dir, ".env")

        # Plik nie istnieje, powinien zostać utworzony
        result_path = find_or_create_env(env_path)

        # Sprawdzenie czy zwrócona ścieżka jest poprawna
        assert result_path == env_path

        # Sprawdzenie czy plik został utworzony
        assert os.path.exists(env_path)

        # Sprawdzenie zawartości pliku
        with open(env_path, 'r') as f:
            content = f.read()

        # Weryfikacja podstawowych zmiennych
        assert "MODEL_NAME" in content
        assert "SERVER_PORT" in content
        assert "TEMPERATURE" in content
        assert "MAX_TOKENS" in content


def test_create_default_env():
    """Test tworzenia domyślnego pliku .env."""
    with tempfile.TemporaryDirectory() as temp_dir:
        # Ścieżka do pliku .env w katalogu tymczasowym
        env_path = os.path.join(temp_dir, ".env")

        # Utworzenie pliku
        create_default_env(env_path)

        # Sprawdzenie czy plik został utworzony
        assert os.path.exists(env_path)

        # Odczytanie pliku
        with open(env_path, 'r') as f:
            content = f.read()

        # Sprawdzenie czy zawiera domyślne wartości
        assert f'MODEL_NAME="{DEFAULT_CONFIG["MODEL_NAME"]}"' in content
        assert f'SERVER_PORT={DEFAULT_CONFIG["SERVER_PORT"]}' in content
        assert f'TEMPERATURE={DEFAULT_CONFIG["TEMPERATURE"]}' in content
        assert f'MAX_TOKENS={DEFAULT_CONFIG["MAX_TOKENS"]}' in content