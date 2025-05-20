from mcp.server.fastmcp import FastMCP, Context
from ollama_client import query_ollama

# Tworzenie serwera MCP
mcp = FastMCP("Prosty serwer MCP z integracją Ollama")

# Narzędzie Ollama
@mcp.tool()
async def ollama_ask(prompt: str, ctx: Context) -> str:
    """Zadaj pytanie do modelu Ollama."""
    await ctx.info(f"Przetwarzanie zapytania: {prompt[:50]}...")
    response = await query_ollama(prompt)
    return response

# Proste narzędzie echo dla testów
@mcp.tool()
def echo(message: str) -> str:
    """Zwraca otrzymaną wiadomość."""
    return f"Otrzymano: {message}"

# Uruchomienie serwera
if __name__ == "__main__":
    print("Uruchamianie serwera MCP z integracją Ollama...")
    mcp.run()
