#!/usr/bin/env python3
"""
Minimalistyczny klient MCP do komunikacji z serwerem TinyLLM
"""

import sys
import requests
import argparse

def send_query(prompt, tool="ask_tinyllm", server_url="http://localhost:8000"):
    """
    Wysyła zapytanie do serwera MCP.

    Args:
        prompt: Zapytanie do modelu
        tool: Nazwa narzędzia (domyślnie ask_tinyllm)
        server_url: URL serwera MCP

    Returns:
        Odpowiedź lub komunikat o błędzie
    """
    print(f"📤 Wysyłanie zapytania do {tool}: {prompt[:50]}...")

    try:
        # Zapytanie do API serwera MCP
        response = requests.post(
            f"{server_url}/v1/tools",
            json={
                "name": tool,
                "arguments": {"prompt" if tool == "ask_tinyllm" else "message": prompt}
            },
            timeout=120  # Dłuższy timeout dla modeli językowych
        )

        if response.status_code == 200:
            result = response.json()
            if "result" in result:
                return result["result"]
            elif "error" in result:
                return f"Błąd: {result['error']}"
            else:
                return "Nieznany format odpowiedzi"
        else:
            return f"Błąd odpowiedzi: {response.status_code} - {response.text}"
    except requests.exceptions.ConnectionError:
        return "⚠️ Błąd połączenia z serwerem MCP. Sprawdź czy serwer jest uruchomiony."
    except Exception as e:
        return f"⚠️ Błąd: {str(e)}"

def main():
    """Główna funkcja klienta."""
    # Parsowanie argumentów wiersza poleceń
    parser = argparse.ArgumentParser(description="Minimalistyczny klient MCP dla TinyLLM")
    parser.add_argument("prompt", help="Zapytanie do wysłania do modelu")
    parser.add_argument("--tool", default="ask_tinyllm", help="Narzędzie do użycia (domyślnie: ask_tinyllm)")
    parser.add_argument("--server", default="http://localhost:8000", help="URL serwera MCP")
    args = parser.parse_args()

    # Wysłanie zapytania
    response = send_query(args.prompt, args.tool, args.server)

    # Wyświetlenie odpowiedzi
    print("\n📥 Odpowiedź:")
    print("=" * 50)
    print(response)
    print("=" * 50)

if __name__ == "__main__":
    main()
