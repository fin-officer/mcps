#!/usr/bin/env python3
"""
Minimalistyczny serwer MCP z integracją Ollama TinyLLM
Wszystko w jednym pliku dla maksymalnej prostoty
"""

import os
import sys
import requests
from mcp.server.fastmcp import FastMCP, Context

# Konfiguracja
OLLAMA_URL = "http://localhost:11434"
MODEL_NAME = "tinyllama"  # Nazwę modelu można zmienić


def check_ollama_available():
    """Sprawdza, czy Ollama jest dostępna i model załadowany."""
    try:
        # Sprawdzenie, czy serwer Ollama działa
        response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=2)
        if response.status_code != 200:
            print(f"⚠️ Błąd: Serwer Ollama nie odpowiada poprawnie. Kod: {response.status_code}")
            return False

        # Sprawdzenie, czy wymagany model jest dostępny
        models = response.json().get("models", [])
        if not any(model["name"] == MODEL_NAME for model in models):
            print(f"⚠️ Model {MODEL_NAME} nie jest dostępny. Dostępne modele:")
            for model in models:
                print(f" - {model['name']}")
            print(f"\nZainstaluj model komendą: ollama pull {MODEL_NAME}")
            return False

        print(f"✅ Ollama działa poprawnie, model {MODEL_NAME} jest dostępny")
        return True
    except requests.exceptions.ConnectionError:
        print("⚠️ Błąd: Nie można połączyć się z serwerem Ollama (port 11434)")
        print("ℹ️ Uruchom Ollama komendą: ollama serve")
        return False
    except Exception as e:
        print(f"⚠️ Błąd: {str(e)}")
        return False


# Tworzenie serwera MCP
mcp = FastMCP("MCP-Ollama-TinyLLM")


@mcp.tool()
async def ask_tinyllm(prompt: str, ctx: Context = None) -> str:
    """Zadaj pytanie do modelu TinyLLM poprzez Ollama."""
    if ctx:
        await ctx.info(f"Wysyłanie zapytania do modelu TinyLLM: {prompt[:50]}...")

    try:
        # Wywołanie API Ollama z minimalną konfiguracją
        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": MODEL_NAME,
                "prompt": prompt,
                "temperature": 0.7,
                "max_tokens": 1000
            },
            timeout=60
        )

        if response.status_code == 200:
            result = response.json()
            return result.get("response", "Brak odpowiedzi od modelu.")
        else:
            error_msg = f"Błąd Ollama: {response.status_code}"
            if ctx:
                await ctx.error(error_msg)
            return error_msg
    except Exception as e:
        error_msg = f"Błąd: {str(e)}"
        if ctx:
            await ctx.error(error_msg)
        return error_msg


@mcp.tool()
def echo(message: str) -> str:
    """Proste narzędzie do testowania działania serwera."""
    return f"Otrzymano: {message}"


if __name__ == "__main__":
    print("🚀 Uruchamianie minimalnego serwera MCP z TinyLLM...")

    # Sprawdzenie dostępności Ollama przed uruchomieniem
    if not check_ollama_available():
        choice = input("Czy chcesz kontynuować mimo to? (t/n): ")
        if choice.lower() != 't':
            print("Zamykanie...")
            sys.exit(1)

    # Uruchomienie serwera MCP
    print("🔌 Uruchamianie serwera MCP na porcie 8000...")
    print("ℹ️ Dostępne narzędzia: ask_tinyllm, echo")

    # Przykładowe zapytania:
    print("\n📝 Przykłady użycia:")
    print(
        "curl -X POST -H \"Content-Type: application/json\" -d '{\"name\":\"echo\",\"arguments\":{\"message\":\"Test\"}}' http://localhost:8000/v1/tools")
    print(
        "curl -X POST -H \"Content-Type: application/json\" -d '{\"name\":\"ask_tinyllm\",\"arguments\":{\"prompt\":\"Co to jest Python?\"}}' http://localhost:8000/v1/tools")

    mcp.run()