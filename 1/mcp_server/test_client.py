import asyncio
import sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def run_test():
    # Parametry dla połączenia stdio do lokalnego skryptu
    server_params = StdioServerParameters(
        command="python",
        args=["mcp_server/simple_fastmcp_server.py"]
    )

    try:
        print("Łączenie z serwerem MCP...")
        # Nawiązanie połączenia z serwerem
        async with stdio_client(server_params) as (read, write):
            async with ClientSession(read, write) as session:
                # Inicjalizacja połączenia
                await session.initialize()

                # Listowanie dostępnych narzędzi
                tools = await session.list_tools()
                print(f"Dostępne narzędzia: {[tool.name for tool in tools]}")

                # Wywołanie narzędzia echo
                if any(tool.name == "echo" for tool in tools):
                    print("Wywołanie narzędzia 'echo'...")
                    result = await session.call_tool("echo", {"message": "Testowa wiadomość"})
                    print(f"Otrzymana odpowiedź: {result.text}")
                else:
                    print("Narzędzie 'echo' nie jest dostępne")

                # Wywołanie narzędzia calculate
                if any(tool.name == "calculate" for tool in tools):
                    print("Wywołanie narzędzia 'calculate'...")
                    result = await session.call_tool("calculate", {"operation": "add", "a": 5, "b": 3})
                    print(f"Wynik dodawania: {result.text}")

                    result = await session.call_tool("calculate", {"operation": "multiply", "a": 4, "b": 7})
                    print(f"Wynik mnożenia: {result.text}")
                else:
                    print("Narzędzie 'calculate' nie jest dostępne")

                print("Test zakończony pomyślnie!")

    except Exception as e:
        print(f"Błąd podczas testu: {str(e)}")
        print(f"Typ wyjątku: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return False

    return True

if __name__ == "__main__":
    success = asyncio.run(run_test())
    # Ustawienie kodu wyjścia na podstawie wyniku testu
    sys.exit(0 if success else 1)
