from mcp.server.fastmcp import FastMCP

# Tworzenie serwera MCP
mcp = FastMCP("Prosty serwer testowy")

# Proste narzędzie echo
@mcp.tool()
def echo(message: str) -> str:
    """Zwraca otrzymaną wiadomość."""
    return f"Otrzymano: {message}"

# Proste narzędzie kalkulacyjne
@mcp.tool()
def calculate(operation: str, a: float, b: float) -> str:
    """Wykonuje podstawowe operacje matematyczne."""
    if operation == "add":
        result = a + b
    elif operation == "subtract":
        result = a - b
    elif operation == "multiply":
        result = a * b
    elif operation == "divide":
        if b == 0:
            return "Błąd: Dzielenie przez zero"
        result = a / b
    else:
        return f"Nieznana operacja: {operation}"

    return f"Wynik {a} {operation} {b} = {result}"

# Uruchomienie serwera
if __name__ == "__main__":
    print("Uruchamianie serwera MCP (FastMCP)...")
    mcp.run()
