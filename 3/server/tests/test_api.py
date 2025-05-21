"""
Testy dla modułu API.
"""

import pytest
import json
from unittest.mock import patch, MagicMock

from ollama_server.server import create_app
from ollama_server.models import OllamaClient


@pytest.fixture
def app():
    """Tworzy instancję aplikacji Flask do testów."""
    app = create_app()
    app.config['TESTING'] = True
    app.config['MODEL_NAME'] = "test-model:latest"
    app.config['TEMPERATURE'] = 0.5
    app.config['MAX_TOKENS'] = 500
    return app


@pytest.fixture
def client(app):
    """Tworzy klienta do testowania API."""
    return app.test_client()


@patch.object(OllamaClient, 'check_availability')
@patch.object(OllamaClient, 'list_models')
def test_list_models(mock_list_models, mock_check_availability, client):
    """Test endpointu /api/models."""
    # Przygotowanie mocków
    mock_check_availability.return_value = True
    mock_list_models.return_value = [
        {"name": "test-model:latest", "size": 1000},
        {"name": "other-model:latest", "size": 2000}
    ]

    # Wywołanie endpointu
    response = client.get('/api/models')

    # Sprawdzenie odpowiedzi
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "models" in data
    assert len(data["models"]) == 2
    assert data["models"][0]["name"] == "test-model:latest"
    assert data["models"][0]["current"] == True
    assert data["models"][1]["name"] == "other-model:latest"
    assert data["models"][1]["current"] == False


@patch.object(OllamaClient, 'check_availability')
@patch.object(OllamaClient, 'check_model_availability')
@patch.object(OllamaClient, 'generate')
def test_ask_endpoint(mock_generate, mock_check_model, mock_check_availability, client):
    """Test endpointu /api/ask."""
    # Przygotowanie mocków
    mock_check_availability.return_value = True
    mock_check_model.return_value = True
    mock_generate.return_value = "To jest testowa odpowiedź."

    # Wywołanie endpointu
    response = client.post('/api/ask', json={
        "prompt": "Testowe zapytanie",
        "temperature": 0.7,
        "max_tokens": 1000
    })

    # Sprawdzenie odpowiedzi
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "response" in data
    assert data["response"] == "To jest testowa odpowiedź."

    # Sprawdzenie wywołania metody generate z poprawnymi parametrami
    mock_generate.assert_called_once_with(
        model_name="test-model:latest",
        prompt="Testowe zapytanie",
        temperature=0.7,
        max_tokens=1000
    )


@patch.object(OllamaClient, 'check_availability')
def test_ask_endpoint_missing_prompt(mock_check_availability, client):
    """Test endpointu /api/ask z brakującym promptem."""
    # Przygotowanie mocków
    mock_check_availability.return_value = True

    # Wywołanie endpointu bez promptu
    response = client.post('/api/ask', json={
        "temperature": 0.7,
        "max_tokens": 1000
    })

    # Sprawdzenie odpowiedzi
    assert response.status_code == 400
    data = json.loads(response.data)
    assert "error" in data


@patch.object(OllamaClient, 'check_availability')
def test_ask_endpoint_ollama_unavailable(mock_check_availability, client):
    """Test endpointu /api/ask gdy Ollama jest niedostępna."""
    # Przygotowanie mocków
    mock_check_availability.return_value = False

    # Wywołanie endpointu
    response = client.post('/api/ask', json={
        "prompt": "Testowe zapytanie"
    })

    # Sprawdzenie odpowiedzi
    assert response.status_code == 503
    data = json.loads(response.data)
    assert "error" in data
    assert "Ollama" in data["error"]


def test_echo_endpoint(client):
    """Test endpointu /api/echo."""
    # Wywołanie endpointu
    response = client.post('/api/echo', json={
        "message": "Test"
    })

    # Sprawdzenie odpowiedzi
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "response" in data
    assert data["response"] == "Otrzymano: Test"


@patch.object(OllamaClient, 'check_availability')
@patch.object(OllamaClient, 'check_model_availability')
@patch.object(OllamaClient, 'pull_model')
def test_switch_model(mock_pull_model, mock_check_model, mock_check_availability, client):
    """Test endpointu /api/switch_model."""
    # Przygotowanie mocków
    mock_check_availability.return_value = True
    mock_check_model.return_value = True
    mock_pull_model.return_value = True

    # Wywołanie endpointu
    response = client.post('/api/switch_model', json={
        "model_name": "new-model:latest"
    })

    # Sprawdzenie odpowiedzi
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "success" in data
    assert data["success"] == True
    assert data["model"] == "new-model:latest"