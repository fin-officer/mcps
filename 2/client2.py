#!/usr/bin/env python3
"""
Super prosty klient do komunikacji z serwerem TinyLLM.
Nie wymaga żadnych specjalnych bibliotek poza requests.
"""

import sys
import requests
import argparse


def send_query(prompt, server_url="http://localhost:5000"):
    """
    Wysyła zapytanie do serwera TinyLLM.

    Args:
        prompt: Zapytanie do modelu
        server_url: URL serwera

    Returns:
        Odpowiedź lub komunikat o błędzie
    """
    print(f"📤 Wysyłanie zapytania: {prompt[:50]}...")

    try:
        # Zapytanie do API serwera
        response = requests.post(
            f"{server_url}/ask",
            json={"prompt": prompt},
            timeout=120  # Dłuższy timeout dla modeli językowych
        )

        if response.status_code == 200:
            result = response.json()
            if "response" in result:
                return result["response"]
            elif "error" in result:
                return f"Błąd: {result['error']}"
            else:
                return "Nieznany format odpowiedzi"
        else:
            return f"Błąd odpowiedzi: {response.status_code} - {response.text}"
    except requests.exceptions.ConnectionError:
        return "⚠️ Błąd połączenia z serwerem. Sprawdź czy serwer jest uruchomiony."
    except Exception as e:
        return f"⚠️ Błąd: {str(e)}"


def test_echo(message="Test", server_url="http://localhost:5000"):
    """
    Testuje działanie serwera używając endpointu echo.

    Args:
        message: Wiadomość testowa
        server_url: URL serwera

    Returns:
        True jeśli test się powiódł, False w przeciwnym razie
    """
    print(f"🧪 Testowanie serwera za pomocą echo...")

    try:
        response = requests.post(
            f"{server_url}/echo",
            json={"message": message},
            timeout=5
        )

        if response.status_code == 200:
            result = response.json()
            print(f"✅ Odpowiedź serwera: {result.get('response', '')}")
            return True
        else:
            print(f"❌ Błąd odpowiedzi: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Błąd: {str(e)}")
        return False


def main():
    """Główna funkcja klienta."""
    # Parsowanie argumentów wiersza poleceń
    parser = argparse.ArgumentParser(description="Super prosty klient TinyLLM")
    parser.add_argument("prompt", nargs='?', help="Zapytanie do wysłania do modelu")
    parser.add_argument("--server", default="http://localhost:5000",
                        help="URL serwera (domyślnie: http://localhost:5000)")
    parser.add_argument("--test", action="store_true", help="Testuje połączenie z serwerem")
    args = parser.parse_args()

    # Jeśli podano opcję --test, wykonaj test echo
    if args.test:
        test_success = test_echo(server_url=args.server)
        if not test_success:
            print("❌ Test nie powiódł się. Czy serwer jest uruchomiony?")
            sys.exit(1)
        print("✅ Test zakończony pomyślnie!")

        # Jeśli nie podano zapytania, zakończ po teście
        if not args.prompt:
            sys.exit(0)

    # Sprawdź czy podano zapytanie
    if not args.prompt:
        parser.print_help()
        sys.exit(1)

    # Wysłanie zapytania
    response = send_query(args.prompt, args.server)

    # Wyświetlenie odpowiedzi
    print("\n📥 Odpowiedź:")
    print("=" * 50)
    print(response)
    print("=" * 50)


if __name__ == "__main__":
    main()