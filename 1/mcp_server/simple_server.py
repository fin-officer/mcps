import os
import sqlite3
import asyncio
from mcp.server import Server, Tool

# Definicja prostego narzędzia
class SimpleTool(Tool):
    """Proste narzędzie testowe."""

    async def call(self, arguments):
        # Metoda wywoływana, gdy narzędzie jest używane
        message = arguments.get("message", "brak wiadomości")
        return f"Otrzymano wiadomość: {message}"

# Inicjalizacja serwera MCP
server = Server()

# Rejestracja narzędzia
server.register_tool(SimpleTool(name="echo", description="Proste narzędzie echo"))

# Główna funkcja uruchamiająca serwer
async def run_server():
    from mcp.server.stdio import stdio_server

    print("Uruchamianie serwera MCP w trybie stdio...")

    # Uruchomienie serwera w trybie stdio
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options(
                server_name="Simple MCP Server",
                server_version="1.0.0"
            )
        )

# Uruchomienie serwera
if __name__ == "__main__":
    asyncio.run(run_server())
