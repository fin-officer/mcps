import asyncio
import httpx
import json

async def test_ollama_api():
    """Bezpośredni test API Ollama bez MCP."""
    print("Wykonywanie bezpośredniego testu API Ollama...")

    api_url = "http://localhost:11434/api/generate"

    data = {
        "model": "tinyllama",
        "prompt": "Napisz jedno zdanie o Polsce.",
        "temperature": 0.7,
        "max_tokens": 100
    }

    try:
        # Sprawdzenie czy serwer Ollama jest dostępny
        async with httpx.AsyncClient(timeout=5) as client:
            try:
                models_response = await client.get("http://localhost:11434/api/tags")
                if models_response.status_code == 200:
                    models = models_response.json().get("models", [])
                    print(f"Dostępne modele Ollama: {[model['name'] for model in models]}")

                    # Sprawdzenie czy model tinyllama jest dostępny
                    if not any(model["name"] == "tinyllama" for model in models):
                        print("UWAGA: Model 'tinyllama' nie jest zainstalowany!")
                        print("Zainstaluj go komendą: ollama pull tinyllama")
                else:
                    print(f"Błąd przy pobieraniu listy modeli: {models_response.status_code}")
            except Exception as e:
                print(f"Nie można pobrać listy modeli: {str(e)}")

        # Wysłanie zapytania do API
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(api_url, json=data)

            if response.status_code == 200:
                result = response.json()
                print(f"Odpowiedź Ollama: {result.get('response', 'Brak odpowiedzi')}")
                return True
            else:
                print(f"Błąd odpowiedzi: {response.status_code}")
                print(f"Treść odpowiedzi: {response.text}")
                return False

    except httpx.ConnectError:
        print("Błąd połączenia z serwerem Ollama. Czy serwer Ollama jest uruchomiony?")
        print("Aby uruchomić serwer Ollama, wpisz w terminalu: ollama serve")
        return False
    except Exception as e:
        print(f"Nieoczekiwany błąd: {str(e)}")
        return False

if __name__ == "__main__":
    asyncio.run(test_ollama_api())
