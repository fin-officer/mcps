import argparse
import requests
import json
import time

def test_ollama_api(model_name):
    """
    Testuje API Ollama z podanym modelem.

    Args:
        model_name: Nazwa modelu do użycia
    """
    base_url = "http://localhost:11434/api"

    print(f"\n=== Test API Ollama z modelem {model_name} ===\n")

    # Sprawdzenie informacji o modelu
    try:
        response = requests.get(f"{base_url}/tags")
        if response.status_code == 200:
            models = response.json().get("models", [])

            # Sprawdzenie czy wybrany model jest dostępny
            model_exists = any(model["name"] == model_name for model in models)

            if model_exists:
                print(f"Model {model_name} jest dostępny.")
            else:
                print(f"UWAGA: Model {model_name} nie jest dostępny. Dostępne modele:")
                for model in models:
                    print(f" - {model['name']}")
                return False
        else:
            print(f"Błąd podczas sprawdzania modeli: {response.status_code}")
            return False
    except Exception as e:
        print(f"Błąd podczas komunikacji z API Ollama: {str(e)}")
        return False

    # Wysłanie zapytania
    prompt = "Co to jest Python? Odpowiedz w 2-3 zdaniach."

    try:
        print(f"\nWysyłanie zapytania: '{prompt}'")

        # Parametry generacji
        params = {
            "model": model_name,
            "prompt": prompt,
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": 100,
            "stream": False
        }

        start_time = time.time()

        # Wywołanie API
        response = requests.post(f"{base_url}/generate", json=params)

        end_time = time.time()

        if response.status_code == 200:
            result = response.json()
            print(f"\nOdpowiedź (czas: {end_time - start_time:.2f}s):")
            print(f"-" * 50)
            print(result.get("response", "Brak odpowiedzi"))
            print(f"-" * 50)
            print(f"Tokeny wejściowe: {result.get('prompt_eval_count', 'N/A')}")
            print(f"Tokeny wyjściowe: {result.get('eval_count', 'N/A')}")
            return True
        else:
            print(f"Błąd odpowiedzi: {response.status_code}")
            print(f"Treść: {response.text}")
            return False
    except Exception as e:
        print(f"Błąd podczas komunikacji z API Ollama: {str(e)}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test API Ollama")
    parser.add_argument("model", help="Nazwa modelu do testowania")
    args = parser.parse_args()

    test_ollama_api(args.model)
