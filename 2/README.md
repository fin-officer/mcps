# Minimalistyczny MCP z TinyLLM

Prosty, łatwy w użyciu serwer i klient Model Context Protocol (MCP) integrujący się z modelem TinyLLM przez Ollama.

## Dlaczego jest to proste rozwiązanie?

Problem integracji MCP z modelami językowymi często jest niepotrzebnie skomplikowany przez:
- Zbyt wiele zależności i warstw abstrakcji
- Skomplikowane API i nieaktualne przykłady
- Założenie o narzędziach, które nie zawsze są dostępne (`uv`, Claude Desktop)

To rozwiązanie redukuje wszystko do absolutnego minimum.

## Wymagania

1. **Python 3.8+**
2. **Pakiety**: `mcp`, `requests`
3. **Ollama**: [https://ollama.com/download](https://ollama.com/download)
4. **Model**: TinyLLM (`ollama pull tinyllama`)

## Szybki start

### 1. Uruchomienie wszystkiego jednym poleceniem

```bash
chmod +x server.sh
./server.sh
```

Skrypt:
- Sprawdzi i zainstaluje wymagane pakiety
- Sprawdzi czy Ollama jest zainstalowana i uruchomiona
- Pobierze model TinyLLM jeśli nie jest dostępny
- Uruchomi serwer MCP

### 2. Zadawanie pytań do modelu

W nowym terminalu:

```bash
./ask.sh "Co to jest Python?"
```

Lub użyj `curl` bezpośrednio:

```bash
curl -X POST -H "Content-Type: application/json" \
     -d '{"name":"ask_tinyllm","arguments":{"prompt":"Co to jest Python?"}}' \
     http://localhost:8000/v1/tools
```

## Jak to działa?

### Architektura

```
[Klient] --> [Serwer MCP] --> [Ollama API] --> [TinyLLM]
```

### Komponenty

1. **minimal_mcp_ollama.py** - serwer MCP udostępniający dwa narzędzia:
   - `ask_tinyllm` - przekazuje zapytanie do modelu TinyLLM
   - `echo` - proste narzędzie do testowania

2. **minimal_mcp_client.py** - minimalistyczny klient do komunikacji z serwerem

3. **server.sh** - skrypt konfiguracyjny i startowy

4. **ask_tinyllm.sh** - wygodny alias do korzystania z klienta

## Korzystanie z API

### API MCP (port 8000)

Serwer udostępnia narzędzia przez standardowe API MCP:

```
POST http://localhost:8000/v1/tools
```

Format zapytania:
```json
{
  "name": "ask_tinyllm",
  "arguments": {
    "prompt": "Twoje pytanie tutaj"
  }
}
```

### Bezpośrednie API Ollama (port 11434)

Możesz również komunikować się z Ollama bezpośrednio:

```bash
curl -X POST http://localhost:11434/api/generate \
     -d '{"model": "tinyllama", "prompt": "Co to jest Python?"}'
```

## Co dalej?

Ten minimalistyczny przykład można łatwo rozszerzyć:

1. Dodaj więcej narzędzi do serwera MCP
2. Zintegruj z innymi modelami Ollama
3. Dodaj obsługę parametrów modelu (temperatura, długość odpowiedzi)
4. Dodaj obsługę komunikacji strumieniowej (streaming)

## Rozwiązywanie problemów

### Problem: Nie można połączyć z serwerem Ollama

**Rozwiązanie**: Uruchom serwer Ollama w nowym terminalu:
```bash
ollama serve
```

### Problem: Model tinyllama nie jest dostępny

**Rozwiązanie**: Pobierz model:
```bash
ollama pull tinyllama
```

### Problem: Błędy MCP

**Rozwiązanie**: Sprawdź czy masz zainstalowane wymagane pakiety:
```bash
pip install mcp requests
```

## Porównanie z innymi rozwiązaniami

1. **Oficjalne SDK MCP**:
   - Zalety: Więcej funkcji, lepsza dokumentacja
   - Wady: Bardziej złożone, więcej zależności, problemy z kompatybilnością

2. **Rozwiązanie minimalistyczne (to)**:
   - Zalety: Proste, minimalne zależności, łatwe do zrozumienia i modyfikacji
   - Wady: Mniej funkcji, podstawowa implementacja

## Konkluzja

Ten minimalny przykład pokazuje, że integracja MCP z modelami językowymi może być prosta i bezproblemowa, eliminując niepotrzebne warstwy złożoności.