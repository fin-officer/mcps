import json
import httpx
from mcp.server.fastmcp import Context
from ollama_config import OLLAMA_CONFIG, GENERATION_PARAMS

async def generate_ollama_response(prompt: str, ctx: Context = None) -> str:
    """
    Funkcja do generowania odpowiedzi z modelu Ollama Tiny.

    Args:
        prompt: Tekst zapytania do modelu
        ctx: Kontekst MCP (opcjonalny)

    Returns:
        Odpowiedź z modelu Ollama
    """
    if ctx:
        await ctx.info(f"Wysyłanie zapytania do modelu Ollama {OLLAMA_CONFIG['model']}...")

    url = f"{OLLAMA_CONFIG['base_url']}/api/generate"

    # Przygotowanie danych zapytania
    data = {
        "model": OLLAMA_CONFIG["model"],
        "prompt": prompt,
        **GENERATION_PARAMS
    }

    try:
        # Wykonanie zapytania do API Ollama
        async with httpx.AsyncClient(timeout=OLLAMA_CONFIG["timeout"]) as client:
            response = await client.post(
                url,
                json=data,
                headers={"Content-Type": "application/json"}
            )

            # Sprawdzenie odpowiedzi
            if response.status_code != 200:
                error_message = f"Błąd komunikacji z Ollama: {response.status_code}"
                if ctx:
                    await ctx.error(error_message)
                return error_message

            # Przetwarzanie odpowiedzi
            try:
                result = response.json()
                return result.get("response", "Brak odpowiedzi od modelu.")
            except json.JSONDecodeError:
                error_message = "Błąd przetwarzania odpowiedzi z Ollama (nieprawidłowy JSON)"
                if ctx:
                    await ctx.error(error_message)
                return error_message

    except httpx.HTTPError as e:
        error_message = f"Błąd HTTP podczas komunikacji z Ollama: {str(e)}"
        if ctx:
            await ctx.error(error_message)
        return error_message
    except Exception as e:
        error_message = f"Nieoczekiwany błąd podczas komunikacji z Ollama: {str(e)}"
        if ctx:
            await ctx.error(error_message)
        return error_message
