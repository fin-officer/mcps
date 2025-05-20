import argparse
import requests
import json
import time
import sys

def test_ollama_streaming(model_name):
    """
    Testuje strumieniowe API Ollama z podanym modelem.

    Args:
        model_name: Nazwa modelu do użycia
    """
    base_url = "http://localhost:11434/api"

    print(f"\n=== Test strumieniowego API Ollama z modelem {model_name} ===\n")

    # Wysłanie zapytania
    prompt = "Napisz krótkie opowiadanie o misiu, który lubi miód. Max 100 słów."

    try:
        print(f"Wysyłanie zapytania: '{prompt}'")
        print(f"Strumieniowa odpowiedź:\n{'-' * 50}")

        # Parametry generacji
        params = {
            "model": model_name,
            "prompt": prompt,
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": 200,
            "stream": True
        }

        start_time = time.time()

        # Wywołanie API w trybie strumieniowym
        with requests.post(f"{base_url}/generate", json=params, stream=True) as response:
            if response.status_code != 200:
                print(f"Błąd odpowiedzi: {response.status_code}")
                print(f"Treść: {response.text}")
                return False

            total_tokens = 0

            # Przetwarzanie strumieniowej odpowiedzi
            for line in response.iter_lines():
                if line:
                    try:
                        chunk = json.loads(line)
                        response_piece = chunk.get("response", "")
                        sys.stdout.write(response_piece)
                        sys.stdout.flush()

                        # Zliczanie tokenów
                        if "eval_count" in chunk:
                            total_tokens = chunk["eval_count"]

                        # Sprawdzanie zakończenia
                        if chunk.get("done", False):
                            break
                    except json.JSONDecodeError:
                        print(f"Błąd dekodowania JSON: {line}")

        end_time = time.time()

        print(f"\n{'-' * 50}")
        print(f"Czas generacji: {end_time - start_time:.2f}s")
        print(f"Wygenerowane tokeny: {total_tokens}")
        return True

    except Exception as e:
        print(f"Błąd podczas komunikacji z API Ollama: {str(e)}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test strumieniowego API Ollama")
    parser.add_argument("model", help="Nazwa modelu do testowania")
    args = parser.parse_args()

    test_ollama_streaming(args.model)
