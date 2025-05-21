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





# Proste rozwiązanie dla TinyLLM - bez MCP


1. **server2.py** - prosty serwer HTTP z endpointami do komunikacji z TinyLLM
2. **client2.py** - klient do komunikacji z serwerem
3. **start_super_simple.sh** - skrypt uruchamiający całe rozwiązanie

## Jak to uruchomić?

1. Zapisz wszystkie trzy pliki w tym samym katalogu
2. Nadaj uprawnienia do wykonania skryptom:
   ```bash
   chmod +x start_super_simple.sh server2.py client.py ask_tinyllm_simple.sh
   ```
3. Uruchom skrypt startowy:
   ```bash
   ./server2.sh
   ```

## Jak korzystać z rozwiązania?

Po uruchomieniu serwera, możesz zadawać pytania do TinyLLM na kilka sposobów:

### 1. Użyj skryptu klienta

W nowym terminalu:
```bash
./ask.sh "Co to jest Python?"
```

### 2. Użyj curl

```bash
curl -X POST -H "Content-Type: application/json" -d '{"prompt":"Co to jest Python?"}' http://localhost:5000/ask
```

### 3. Przeglądarka internetowa

Otwórz `http://localhost:5000` w przeglądarce, aby zobaczyć interfejs z instrukcjami.

## Zalety tego rozwiązania

1. **Minimalne zależności** - potrzebujesz tylko Flask i requests, bez MCP
2. **Proste API** - endpointy `/ask` i `/echo` z komunikacją JSON
3. **Niezawodność** - eliminuje problemy z kompatybilnością MCP
4. **Lepsze debugowanie** - jasne komunikaty błędów
5. **Interfejs web** - dostępny pod adresem http://localhost:5000
6. **Obsługa błędów** - sprawdzanie dostępności Ollama i modelu

## Diagnostyka problemów

Jeśli nadal napotykasz problemy:

1. **Czy Ollama jest uruchomiona?** Sprawdź czy serwer Ollama działa, uruchamiając:
   ```bash
   curl http://localhost:11434/api/tags
   ```

2. **Czy model TinyLLM jest dostępny?** Sprawdź listę modeli:
   ```bash
   ollama list
   ```

3. **Test połączenia z serwerem**:
   ```bash
   ./client.py --test
   ```

## Porównanie z MCP

| Aspekt | MCP | Super proste rozwiązanie |
|--------|-----|-------------------------|
| Zależności | Wymaga MCP SDK, wiele warstw | Tylko Flask i requests |
| Stabilność | Problemy z kompatybilnością | Proste, stabilne API |
| Debugowanie | Skomplikowane błędy | Czytelne komunikaty |
| Interfejs | Brak | Prosty interfejs web |
| Konfiguracja | Złożona | Minimalna |

To rozwiązanie może służyć jako prosty punkt startowy, który możesz później rozbudować o bardziej zaawansowane funkcje, gdy podstawowa integracja będzie już działać.

# Serwer Ollama z Wyborem Modeli

Kompletne rozwiązanie do uruchamiania i zarządzania lokalnym serwerem modeli językowych poprzez Ollama.

## Funkcje

- 🚀 Łatwa konfiguracja i zarządzanie modelami Ollama
- 📝 Interfejs web do testowania modeli
- ⚙️ Konfiguracja przez plik .env
- 🌐 API REST do integracji z aplikacjami
- 🔄 Obsługa wielu modeli z możliwością przełączania
- 📊 Zaawansowane zarządzanie parametrami generowania

## Wymagania

- Python 3.8+
- Flask i requests (`pip install flask requests python-dotenv`)
- [Ollama](https://ollama.com/download)
- Co najmniej jeden model Ollama (np. tinyllama, llama2, phi)

## Instalacja

1. Sklonuj to repozytorium lub pobierz pliki
2. Zainstaluj wymagane pakiety:
   ```bash
   pip install flask requests python-dotenv
   ```
3. Zainstaluj i uruchom Ollama:
   ```bash
   # Instalacja ze strony https://ollama.com/download
   ollama serve  # Uruchom serwer Ollama
   ```

## Szybki start

1. **Skonfiguruj model**:
   ```bash
   ./model.sh
   ```
   
   Skrypt pomoże Ci wybrać i pobrać model, a następnie skonfigurować plik .env.

2. **Uruchom serwer**:
   ```bash
   python server.py
   ```
   
   Serwer uruchomi się domyślnie na porcie 5001.

3. **Używaj interfejsu web**:
   
   Otwórz przeglądarkę i przejdź do: http://localhost:5001

4. **Lub korzystaj z API bezpośrednio**:
   ```bash
   ./ask.sh "Co to jest Python?"
   ```

## Struktura projektu

- `model.sh` - Skrypt do konfiguracji i pobierania modeli Ollama
- `server.py` - Główny serwer Flask z interfejsem web i API REST
- `env_loader.py` - Moduł do ładowania konfiguracji z pliku .env
- `ask.sh` - Skrypt klienta do zadawania pytań
- `.env` - Plik konfiguracyjny (tworzony automatycznie)

## Plik .env

Plik `.env` zawiera konfigurację serwera i jest tworzony automatycznie przez skrypt `model.sh` lub moduł `env_loader.py`. Przykładowa zawartość:

```
# Konfiguracja modelu Ollama
MODEL_NAME="tinyllama:latest"

# Konfiguracja serwera
OLLAMA_URL="http://localhost:11434"
SERVER_PORT=5001

# Parametry generowania
TEMPERATURE=0.7
MAX_TOKENS=1000
```

## API REST

Serwer udostępnia następujące endpointy:

### `POST /ask`

Wysyła zapytanie do modelu Ollama.

**Żądanie**:
```json
{
  "prompt": "Co to jest Python?",
  "temperature": 0.7,
  "max_tokens": 1000
}
```

**Odpowiedź**:
```json
{
  "response": "Python to wysokopoziomowy, interpretowany język programowania..."
}
```

### `GET /models`

Pobiera listę dostępnych modeli Ollama.

**Odpowiedź**:
```json
{
  "models": [
    {
      "name": "tinyllama:latest",
      "size": 1640,
      "current": true
    },
    {
      "name": "llama2:latest",
      "size": 3827,
      "current": false
    }
  ]
}
```

### `POST /echo`

Proste narzędzie do testowania działania serwera.

**Żądanie**:
```json
{
  "message": "Test"
}
```

**Odpowiedź**:
```json
{
  "response": "Otrzymano: Test"
}
```

## Przykłady użycia

### Z cURL

```bash
# Zapytanie do modelu
curl -X POST -H "Content-Type: application/json" \
     -d '{"prompt":"Co to jest Python?"}' \
     http://localhost:5001/ask

# Pobranie listy modeli
curl http://localhost:5001/models

# Test echo
curl -X POST -H "Content-Type: application/json" \
     -d '{"message":"Test"}' \
     http://localhost:5001/echo
```

### Z Python

```python
import requests

# Zapytanie do modelu
response = requests.post(
    "http://localhost:5001/ask",
    json={"prompt": "Co to jest Python?"}
)
print(response.json()["response"])

# Pobranie listy modeli
models = requests.get("http://localhost:5001/models").json()["models"]
print(models)
```

## Zaawansowane użycie

### Zmiana modelu

Możesz zmienić model na dwa sposoby:

1. **Ponowna konfiguracja**:
   ```bash
   ./model.sh
   ```

2. **Aktualizacja pliku .env**:
   Edytuj plik `.env` i zmień wartość `MODEL_NAME`, a następnie zrestartuj serwer.

3. **Aktualizacja przez Python**:
   ```bash
   python env_loader.py "gemma:latest"
   ```

### Bezpośrednie zapytanie do Ollama

Możesz pominąć serwer Flask i wysyłać zapytania bezpośrednio do Ollama:

```bash
./ask.sh "Czym jest sztuczna inteligencja?" --direct
```

## Rozwiązywanie problemów

### Nie można połączyć z Ollama

Upewnij się, że serwer Ollama jest uruchomiony:

```bash
ollama serve
```

### Model nie jest dostępny

Pobierz model za pomocą:

```bash
ollama pull tinyllama
```

### Błąd parsowania JSON

Jeśli otrzymujesz błąd parsowania JSON, spróbuj zaktualizować skrypt `ask.sh` lub użyj interfejsu web.


