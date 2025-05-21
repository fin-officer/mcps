#!/bin/bash
# Skrypt do uruchomienia serwera Ollama i server.py
# Działa niezależnie od platformy

# Kolory dla lepszej czytelności
if [[ -t 1 ]]; then  # Sprawdzenie czy terminal obsługuje kolory
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'  # No Color
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    NC=''
fi

# Funkcja do sprawdzania czy proces działa
is_process_running() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ps -p $1 &> /dev/null
    else
        # Linux
        kill -0 $1 &> /dev/null 2>&1
    fi
    return $?
}

# Funkcja do uruchomienia Ollama w tle
start_ollama() {
    echo -e "${BLUE}Uruchamianie serwera Ollama...${NC}"

    if ! command -v ollama &> /dev/null; then
        echo -e "${RED}Błąd: Ollama nie jest zainstalowana${NC}"
        echo -e "${YELLOW}Pobierz Ollama ze strony: https://ollama.com/download${NC}"
        return 1
    fi

    # Sprawdzenie czy Ollama już działa
    if curl -s --head --connect-timeout 2 http://localhost:11434 &> /dev/null; then
        echo -e "${GREEN}✓ Serwer Ollama już działa${NC}"
        return 0
    fi

    # Uruchomienie Ollamy w tle
    echo -e "${YELLOW}Uruchamianie serwera Ollama w tle...${NC}"
    ollama serve > ollama.log 2>&1 &
    OLLAMA_PID=$!

    # Zapisanie PID do pliku
    echo $OLLAMA_PID > .ollama.pid

    # Czekanie na uruchomienie serwera
    echo -n "Czekanie na uruchomienie serwera Ollama"
    for i in {1..30}; do
        if curl -s --head --connect-timeout 1 http://localhost:11434 &> /dev/null; then
            echo -e "\n${GREEN}✓ Serwer Ollama został uruchomiony!${NC}"
            return 0
        fi

        # Sprawdzenie czy proces nadal działa
        if ! is_process_running $OLLAMA_PID; then
            echo -e "\n${RED}✗ Proces Ollama zakończył działanie nieoczekiwanie${NC}"
            echo -e "${YELLOW}Sprawdź plik ollama.log aby uzyskać więcej informacji${NC}"
            return 1
        fi

        echo -n "."
        sleep 1
    done

    echo -e "\n${RED}✗ Timeout: Nie udało się uruchomić serwera Ollama w czasie 30 sekund${NC}"
    echo -e "${YELLOW}Sprawdź plik ollama.log aby uzyskać więcej informacji${NC}"
    return 1
}

# Funkcja do uruchomienia serwera API
start_server() {
    echo -e "${BLUE}Uruchamianie serwera API (server.py)...${NC}"

    # Sprawdzenie czy server.py istnieje
    if [ ! -f "server.py" ]; then
        echo -e "${RED}Błąd: Plik server.py nie istnieje${NC}"
        return 1
    fi

    # Sprawdzenie czy Python jest zainstalowany
    if command -v python3 &> /dev/null; then
        PYTHON="python3"
    elif command -v python &> /dev/null; then
        PYTHON="python"
    else
        echo -e "${RED}Błąd: Python nie jest zainstalowany${NC}"
        return 1
    fi

    # Uruchomienie serwera
    echo -e "${GREEN}Uruchamianie serwera na porcie 5001...${NC}"
    echo -e "${YELLOW}Naciśnij Ctrl+C aby zatrzymać serwer${NC}"
    $PYTHON server.py

    return $?
}

# Funkcja do zatrzymania Ollama
cleanup() {
    echo -e "\n${BLUE}Zatrzymywanie procesów...${NC}"

    # Zatrzymanie Ollama jeśli był uruchomiony przez ten skrypt
    if [ -f ".ollama.pid" ]; then
        OLLAMA_PID=$(cat .ollama.pid)
        if is_process_running $OLLAMA_PID; then
            echo -e "${YELLOW}Zatrzymywanie serwera Ollama (PID: $OLLAMA_PID)...${NC}"
            kill $OLLAMA_PID
            rm .ollama.pid
        fi
    fi

    echo -e "${GREEN}Cleanup zakończony${NC}"
    exit 0
}

# Ustaw trap dla Ctrl+C
trap cleanup SIGINT SIGTERM

# Główna funkcja
main() {
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${BLUE}   Uruchamianie środowiska Ollama API   ${NC}"
    echo -e "${BLUE}========================================================${NC}"

    # Uruchomienie Ollama
    start_ollama
    if [ $? -ne 0 ]; then
        echo -e "${RED}Nie udało się uruchomić serwera Ollama${NC}"
        cleanup
        exit 1
    fi

    # Uruchomienie serwera API
    start_server

    # Czyszczenie po zakończeniu
    cleanup
}

# Uruchomienie głównej funkcji
main