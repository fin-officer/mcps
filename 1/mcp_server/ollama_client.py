import httpx
import json
import asyncio
from ollama_config import OLLAMA_CONFIG, GENERATION_PARAMS

async def query_ollama(prompt: str):
    """
    Wysyła zapytanie do Ollama API i zwraca odpowiedź.

    Args:
        prompt: Zapytanie do modelu

    Returns:
        str: Odpowiedź od modelu Ollama lub komunikat błędu
    """
    print(f"Wysyłanie zapytania do Ollama ({OLLAMA_CONFIG['model']}): {prompt[:50]}...")

    # Przygotowanie danych zapytania
    data = {
        "model": OLLAMA_CONFIG["model"],
        "prompt": prompt,
        **GENERATION_PARAMS
    }

    try:
        # Wysłanie zapytania do API Ollama
        async with httpx.AsyncClient(timeout=OLLAMA_CONFIG["timeout"]) as client:
            response = await client.post(
                f"{OLLAMA_CONFIG['base_url']}/api/generate",
                json=data
            )

            if response.status_code != 200:
                return f"Błąd odpowiedzi z Ollama: {response.status_code}"

            # Przetwarzanie odpowiedzi
            try:
                result = response.json()
                return result.get("response", "Brak odpowiedzi od modelu")
            except json.JSONDecodeError:
                return "Błąd przetwarzania odpowiedzi JSON z Ollama"

    except httpx.RequestError as e:
        return f"Błąd połączenia z Ollama: {str(e)}"
    except Exception as e:
        return f"Nieoczekiwany błąd: {str(e)}"

# Prosty test do uruchomienia bezpośrednio
if __name__ == "__main__":
    async def test():
        response = await query_ollama("Powiedz mi coś o Polsce w jednym zdaniu.")
        print(f"Odpowiedź: {response}")

    asyncio.run(test())
