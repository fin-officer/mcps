"""
Moduł do zarządzania modelami Ollama.

Zapewnia funkcje do interakcji z API Ollama, pobieranie i listowanie modeli,
oraz obsługę generowania odpowiedzi.
"""

import json
import logging
import requests
from typing import Dict, List, Optional, Union, Any

# Konfiguracja logowania
logger = logging.getLogger("ollama_server.models")

# Informacje o dostępnych modelach
MODEL_INFO = {
    "llama3": {"size": "8B", "description": "Ogólnego przeznaczenia, dobry do większości zadań"},
    "phi3": {"size": "3.8B", "description": "Szybki, dobry do prostszych zadań, zoptymalizowany pod kątem kodu"},
    "mistral": {"size": "7B", "description": "Ogólnego przeznaczenia, efektywny energetycznie"},
    "gemma": {"size": "7B", "description": "Dobry do zadań języka naturalnego i kreatywnego pisania"},
    "tinyllama": {"size": "1.1B", "description": "Bardzo szybki, idealny dla słabszych urządzeń"},
    "qwen": {"size": "7B", "description": "Dobry w analizie tekstu, wsparcie dla języków azjatyckich"},
    "llava": {"size": "7B", "description": "Multimodalny z obsługą obrazów"},
    "codellama": {"size": "7B", "description": "Wyspecjalizowany model do kodowania"},
    "vicuna": {"size": "7B", "description": "Wytrenowany na konwersacjach, dobry do dialogów"},
    "falcon": {"size": "7B", "description": "Szybki i efektywny, dobry stosunek wydajności do rozmiaru"},
    "orca-mini": {"size": "3B", "description": "Dobry do podstawowych zadań NLP"},
    "wizardcoder": {"size": "13B", "description": "Stworzony do zadań związanych z kodem"},
    "llama2": {"size": "7B", "description": "Sprawdzony w różnych zastosowaniach"},
    "stablelm": {"size": "3B", "description": "Dobry do generowania tekstu i dialogów"},
    "dolphin": {"size": "7B", "description": "Koncentruje się na naturalności dialogów"},
    "neural-chat": {"size": "7B", "description": "Zoptymalizowany pod kątem urządzeń Intel"},
    "starling": {"size": "7B", "description": "Mniejszy ale skuteczny"},
    "openhermes": {"size": "7B", "description": "Dobra dokładność, postępowanie zgodnie z instrukcjami"},
    "yi": {"size": "6B", "description": "Zaawansowany model wielojęzyczny"},
}


class OllamaClient:
    """Klient do komunikacji z API Ollama."""

    def __init__(self, base_url: str = "http://localhost:11434"):
        """
        Inicjalizacja klienta Ollama.

        Args:
            base_url: Bazowy URL serwera Ollama.
        """
        self.base_url = base_url.rstrip("/")
        logger.info(f"Inicjalizacja klienta Ollama dla: {self.base_url}")

    def check_availability(self) -> bool:
        """
        Sprawdza czy serwer Ollama jest dostępny.

        Returns:
            bool: True jeśli serwer jest dostępny, False w przeciwnym razie.
        """
        try:
            response = requests.head(f"{self.base_url}", timeout=2)
            return response.status_code == 200
        except requests.RequestException as e:
            logger.error(f"Błąd podczas sprawdzania dostępności Ollama: {str(e)}")
            return False

    def list_models(self) -> List[Dict[str, Any]]:
        """
        Pobiera listę dostępnych modeli.

        Returns:
            Lista słowników zawierających informacje o modelach.
        """
        try:
            response = requests.get(f"{self.base_url}/api/tags")
            if response.status_code == 200:
                models = response.json().get("models", [])
                # Wzbogać o informacje z MODEL_INFO
                for model in models:
                    name = model.get("name", "").split(":")[0]
                    if name in MODEL_INFO:
                        model["info"] = MODEL_INFO[name]
                return models
            else:
                logger.error(f"Błąd podczas pobierania listy modeli: {response.status_code}")
                return []
        except requests.RequestException as e:
            logger.error(f"Wyjątek podczas pobierania listy modeli: {str(e)}")
            return []

    def check_model_availability(self, model_name: str) -> bool:
        """
        Sprawdza czy dany model jest dostępny.

        Args:
            model_name: Nazwa modelu do sprawdzenia.

        Returns:
            bool: True jeśli model jest dostępny, False w przeciwnym razie.
        """
        models = self.list_models()
        for model in models:
            if model.get("name", "").startswith(model_name):
                return True
        return False

    def pull_model(self, model_name: str) -> bool:
        """
        Pobiera model z repozytorium Ollama.

        Args:
            model_name: Nazwa modelu do pobrania.

        Returns:
            bool: True jeśli operacja zakończyła się sukcesem, False w przeciwnym razie.
        """
        try:
            logger.info(f"Pobieranie modelu: {model_name}")
            response = requests.post(
                f"{self.base_url}/api/pull",
                json={"name": model_name},
                stream=True
            )

            if response.status_code == 200:
                for line in response.iter_lines():
                    if line:
                        data = json.loads(line)
                        logger.info(f"Postęp pobierania: {data.get('status', '')}")
                return True
            else:
                logger.error(f"Błąd podczas pobierania modelu: {response.status_code}")
                return False
        except requests.RequestException as e:
            logger.error(f"Wyjątek podczas pobierania modelu: {str(e)}")
            return False

    def generate(
            self,
            model_name: str,
            prompt: str,
            temperature: float = 0.7,
            max_tokens: int = 1000
    ) -> str:
        """
        Generuje odpowiedź na podstawie promptu.

        Args:
            model_name: Nazwa modelu do użycia.
            prompt: Prompt/zapytanie.
            temperature: Temperatura generowania (0.0-1.0).
            max_tokens: Maksymalna liczba tokenów do wygenerowania.

        Returns:
            str: Wygenerowana odpowiedź.
        """
        try:
            logger.info(f"Generowanie odpowiedzi z modelem: {model_name}")
            payload = {
                "model": model_name,
                "prompt": prompt,
                "temperature": temperature,
                "max_tokens": max_tokens,
                "stream": False
            }

            response = requests.post(
                f"{self.base_url}/api/generate",
                json=payload
            )

            if response.status_code == 200:
                result = response.json()
                return result.get("response", "")
            else:
                error_msg = f"Błąd podczas generowania odpowiedzi: {response.status_code}"
                logger.error(error_msg)
                return f"Błąd: {error_msg}"
        except requests.RequestException as e:
            error_msg = f"Wyjątek podczas generowania odpowiedzi: {str(e)}"
            logger.error(error_msg)
            return f"Błąd: {error_msg}"


def get_model_info(model_name: str) -> Dict[str, str]:
    """
    Pobiera informacje o modelu.

    Args:
        model_name: Nazwa modelu.

    Returns:
        Dict z informacjami o modelu lub pusty słownik, jeśli model nie jest znany.
    """
    # Wyodrębnij nazwę bazową modelu (bez wersji)
    base_name = model_name.split(":")[0]
    return MODEL_INFO.get(base_name, {"size": "?", "description": "Brak informacji"})


if __name__ == "__main__":
    # Jeśli uruchomiony bezpośrednio, wyświetl informacje o wszystkich znanych modelach
    print("Znane modele:")
    for name, info in MODEL_INFO.items():
        print(f"  - {name} ({info['size']}): {info['description']}")