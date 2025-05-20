from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

# Parametry dla połączenia stdio
server_params = StdioServerParameters(
    command="python",  # Wykonywany program
    args=["example_server.py"],  # Opcjonalne argumenty
    env=None,  # Opcjonalne zmienne środowiskowe
)


async def run():
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            # Inicjalizacja połączenia
            await session.initialize()

            # Listowanie dostępnych narzędzi
            tools = await session.list_tools()
            print(f"Dostępne narzędzia: {tools}")

            # Wywołanie narzędzia
            result = await session.call_tool("tool-name", arguments={"arg1": "value"})


if __name__ == "__main__":
    import asyncio

    asyncio.run(run())