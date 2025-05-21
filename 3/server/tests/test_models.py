"""
Testy dla modułu models.
"""

import pytest
import json
from unittest.mock import patch, MagicMock

from ollama_server.models import OllamaClient, get_model_info, MODEL_INFO


def test_get_model_info_known_model():
    """Test pobierania informacji o znanym modelu."""
    # Sprawdzenie dla znanego modelu
    info = get_model_info("llama3")

    # Sprawdzenie czy zwrócone zostały poprawne informacje
    assert info == MODEL_INFO["llama3"]
    assert "size" in info
    assert "description" in info


def test_get_model_info_known_model_with_version():
    """Test pobierania informacji o znanym modelu z wersją."""
    # Sprawdzenie dla znanego modelu z wersją
    info = get_model_info("llama3:latest")

    # Sprawdzenie czy zwrócone zostały poprawne informacje
    assert info == MODEL_INFO["llama3"]


def test_get_model_info_unknown_model():
    """Test pobierania informacji o nieznanym modelu."""
    # Sprawdzenie dla nieznanego modelu
    info = get_model_info("unknown-model")

    # Sprawdzenie czy zwrócone zostały domyślne informacje
    assert "size" in info
    assert "description" in info
    assert info["size"] == "?"
    assert "Brak informacji" in info["description"]


class TestOllamaClient:
    """Testy dla klasy OllamaClient."""

    @pytest.fixture
    def client(self):
        """Fixture tworzący klienta Ollama."""
        return OllamaClient(base_url="http://localhost:11434")

    @patch('requests.head')
    def test_check_availability_success(self, mock_head, client):
        """Test sprawdzania dostępności Ollama - sukces."""
        # Przygotowanie mocka
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_head.return_value = mock_response

        # Wywołanie metody
        result = client.check_availability()

        # Sprawdzenie wyniku
        assert result == True
        mock_head.assert_called_once_with("http://localhost:11434", timeout=2)

    @patch('requests.head')
    def test_check_availability_failure(self, mock_head, client):
        """Test sprawdzania dostępności Ollama - niepowodzenie."""
        # Przygotowanie mocka - błąd połączenia
        mock_head.side_effect = Exception("Connection error")

        # Wywołanie metody
        result = client.check_availability()

        # Sprawdzenie wyniku
        assert result == False

    @patch('requests.get')
    def test_list_models_success(self, mock_get, client):
        """Test listowania modeli - sukces."""
        # Przygotowanie mocka
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "models": [
                {"name": "model1:latest", "size": 1000},
                {"name": "model2:latest", "size": 2000}
            ]
        }
        mock_get.return_value = mock_response

        # Wywołanie metody
        result = client.list_models()

        # Sprawdzenie wyniku
        assert len(result) == 2
        assert result[0]["name"] == "model1:latest"
        assert result[1]["name"] == "model2:latest"
        mock_get.assert_called_once_with("http://localhost:11434/api/tags")

    @patch('requests.get')
    def test_list_models_failure(self, mock_get, client):
        """Test listowania modeli - niepowodzenie."""
        # Przygotowanie mocka - błąd połączenia
        mock_get.side_effect = Exception("Connection error")

        # Wywołanie metody
        result = client.list_models()

        # Sprawdzenie wyniku
        assert result == []

    @patch('requests.post')
    def test_generate_success(self, mock_post, client):
        """Test generowania odpowiedzi - sukces."""
        # Przygotowanie mocka
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "response": "To jest testowa odpowiedź."
        }
        mock_post.return_value = mock_response

        # Wywołanie metody
        result = client.generate(
            model_name="test-model",
            prompt="Testowe zapytanie",
            temperature=0.7,
            max_tokens=1000
        )

        # Sprawdzenie wyniku
        assert result == "To jest testowa odpowiedź."

        # Sprawdzenie czy wykonane zostało poprawne zapytanie
        mock_post.assert_called_once()
        args, kwargs = mock_post.call_args
        assert args[0] == "http://localhost:11434/api/generate"
        assert kwargs["json"]["model"] == "test-model"
        assert kwargs["json"]["prompt"] == "Testowe zapytanie"
        assert kwargs["json"]["temperature"] == 0.7
        assert kwargs["json"]["max_tokens"] == 1000

    @patch('requests.post')
    def test_generate_failure(self, mock_post, client):
        """Test generowania odpowiedzi - niepowodzenie."""
        # Przygotowanie mocka - błąd połączenia
        mock_post.side_effect = Exception("Connection error")

        # Wywołanie metody
        result = client.generate(
            model_name="test-model",
            prompt="Testowe zapytanie"
        )

        # Sprawdzenie wyniku - powinien zawierać komunikat o błędzie
        assert "Błąd" in result
        assert "Connection error" in result

    @patch('ollama_server.models.OllamaClient.list_models')
    def test_check_model_availability_available(self, mock_list_models, client):
        """Test sprawdzania dostępności modelu - model dostępny."""
        # Przygotowanie mocka
        mock_list_models.return_value = [
            {"name": "model1:latest"},
            {"name": "model2:latest"}
        ]

        # Wywołanie metody - model dostępny
        result = client.check_model_availability("model1")

        # Sprawdzenie wyniku
        assert result == True

    @patch('ollama_server.models.OllamaClient.list_models')
    def test_check_model_availability_unavailable(self, mock_list_models, client):
        """Test sprawdzania dostępności modelu - model niedostępny."""
        # Przygotowanie mocka
        mock_list_models.return_value = [
            {"name": "model1:latest"},
            {"name": "model2:latest"}
        ]

        # Wywołanie metody - model niedostępny
        result = client.check_model_availability("model3")

        # Sprawdzenie wyniku
        assert result == False