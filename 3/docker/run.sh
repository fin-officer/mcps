#!/bin/bash
# Skrypt do uruchamiania Ollama API w Docker
# Autor: Tom
# Data: 2025-05-20

# Kolory dla lepszej czytelności
if [[ -t 1 ]]; then  # Sprawdzenie czy terminal obsługuje kolory
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'  # No Color
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    CYAN=''
    NC=''
fi

# Sprawdzenie czy Docker jest zainstalowany
check_docker() {
    echo -e "${BLUE}Sprawdzanie instalacji Docker...${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Błąd: Docker nie jest zainstalowany${NC}"
        echo -e "${YELLOW}Zainstaluj Docker ze strony: https://docs.docker.com/get-docker/${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Docker jest zainstalowany${NC}"
    fi

    # Sprawdzenie czy Docker działa
    if ! docker info &> /dev/null; then
        echo -e "${RED}Błąd: Docker nie jest uruchomiony lub użytkownik nie ma uprawnień${NC}"
        echo -e "${YELLOW}Uruchom Docker lub dodaj użytkownika do grupy docker${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Docker działa poprawnie${NC}"
    fi

    return 0
}

# Sprawdzenie czy Docker Compose jest zainstalowany
check_docker_compose() {
    echo -e "${BLUE}Sprawdzanie instalacji Docker Compose...${NC}"

    # Sprawdzenie docker compose jako plugin
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose (plugin) jest zainstalowany${NC}"
        DOCKER_COMPOSE="docker compose"
        return 0
    fi

    # Sprawdzenie docker-compose jako osobny program
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose (standalone) jest zainstalowany${NC}"
        DOCKER_COMPOSE="docker-compose"
        return 0
    fi

    echo -e "${RED}Błąd: Docker Compose nie jest zainstalowany${NC}"
    echo -e "${YELLOW}Zainstaluj Docker Compose ze strony: https://docs.docker.com/compose/install/${NC}"
    return 1
}

# Sprawdzenie czy pliki Docker istnieją
check_docker_files() {
    echo -e "${BLUE}Sprawdzanie plików Docker...${NC}"

    # Sprawdzenie czy istnieje Dockerfile
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}Błąd: Plik Dockerfile nie istnieje${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Plik Dockerfile istnieje${NC}"
    fi

    # Sprawdzenie czy istnieje docker-compose.yml
    if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
        if [ -f "docker-compose.minimal.yml" ]; then
            echo -e "${YELLOW}⚠ Nie znaleziono standardowego pliku docker-compose.yml, ale znaleziono docker-compose.minimal.yml${NC}"
            echo -e "${YELLOW}Użyję docker-compose.minimal.yml${NC}"
            COMPOSE_FILE="docker-compose.minimal.yml"
        else
            echo -e "${RED}Błąd: Brak pliku docker-compose.yml lub docker-compose.minimal.yml${NC}"
            return 1
        fi
    else
        if [ -f "docker-compose.yml" ]; then
            COMPOSE_FILE="docker-compose.yml"
        else
            COMPOSE_FILE="docker-compose.yaml"
        fi
        echo -e "${GREEN}✓ Plik $COMPOSE_FILE istnieje${NC}"
    fi

    # Sprawdzenie czy istnieje plik server.py
    if [ ! -f "server.py" ]; then
        echo -e "${YELLOW}⚠ Plik server.py nie istnieje w bieżącym katalogu${NC}"
        echo -e "${YELLOW}Będę próbował uruchomić kontenery, ale mogą wystąpić błędy${NC}"
    else
        echo -e "${GREEN}✓ Plik server.py istnieje${NC}"
    fi

    return 0
}

# Sprawdź czy model Ollama jest dostępny
check_model_availability() {
    MODEL_NAME=$1

    echo -e "${BLUE}Sprawdzanie dostępności modelu $MODEL_NAME...${NC}"

    # Uruchomienie kontenera Ollama do sprawdzenia dostępnych modeli
    AVAILABLE_MODELS=$(docker run --rm ollama/ollama list 2>/dev/null || echo "Error")

    if [[ "$AVAILABLE_MODELS" == "Error" ]]; then
        echo -e "${YELLOW}⚠ Nie można sprawdzić dostępnych modeli${NC}"
        echo -e "${YELLOW}Model zostanie pobrany podczas uruchamiania kontenera${NC}"
        return 0
    fi

    if echo "$AVAILABLE_MODELS" | grep -q "$MODEL_NAME"; then
        echo -e "${GREEN}✓ Model $MODEL_NAME jest dostępny${NC}"
    else
        echo -e "${YELLOW}⚠ Model $MODEL_NAME nie jest jeszcze pobrany${NC}"
        echo -e "${YELLOW}Model zostanie pobrany podczas uruchamiania kontenera${NC}"
    fi

    return 0
}

# Uruchom kontenery
start_containers() {
    echo -e "${BLUE}Uruchamianie kontenerów...${NC}"

    # Użycie odpowiedniego pliku compose
    echo -e "${YELLOW}Używam pliku: $COMPOSE_FILE${NC}"

    # Uruchomienie kontenerów
    if $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d; then
        echo -e "${GREEN}✓ Kontenery zostały uruchomione pomyślnie${NC}"
    else
        echo -e "${RED}Błąd podczas uruchamiania kontenerów${NC}"
        return 1
    fi

    return 0
}

# Wyświetl informacje o uruchomionych kontenerach
show_info() {
    echo -e "${BLUE}Informacje o uruchomionych kontenerach:${NC}"

    echo -e "${CYAN}=== Status kontenerów ===${NC}"
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" ps

    # Sprawdź API serwera
    echo -e "\n${CYAN}=== Dostępność API serwera ===${NC}"

    # Odczytanie portu z compose file
    PORT=$(grep -A 5 "api-server" "$COMPOSE_FILE" | grep "\- \".*:.*\"" | head -n 1 | sed -E 's/.*"([0-9]+):([0-9]+)".*/\1/')

    if [ -z "$PORT" ]; then
        PORT=5001 # Domyślny port
    fi

    # Sprawdzenie dostępności API
    sleep 5 # Czekanie na uruchomienie serwera
    if curl -s --head --connect-timeout 5 http://localhost:$PORT &> /dev/null; then
        echo -e "${GREEN}✓ API serwer jest dostępny pod adresem: http://localhost:$PORT${NC}"
    else
        echo -e "${YELLOW}⚠ API serwer nie jest jeszcze dostępny pod adresem: http://localhost:$PORT${NC}"
        echo -e "${YELLOW}Sprawdź logi, aby zobaczyć status uruchamiania:${NC}"
        echo -e "${YELLOW}$DOCKER_COMPOSE -f \"$COMPOSE_FILE\" logs api-server${NC}"
    fi

    echo -e "\n${CYAN}=== Dostępność Ollama ===${NC}"
    if curl -s --head --connect-timeout 5 http://localhost:11434 &> /dev/null; then
        echo -e "${GREEN}✓ Serwer Ollama jest dostępny pod adresem: http://localhost:11434${NC}"

        # Sprawdzenie dostępnych modeli
        echo -e "\n${CYAN}=== Dostępne modele ===${NC}"
        MODELS=$(curl -s http://localhost:11434/api/tags 2>/dev/null | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//')

        if [ -n "$MODELS" ]; then
            echo -e "${GREEN}Modele dostępne na serwerze Ollama:${NC}"
            for model in $MODELS; do
                echo -e "  - $model"
            done
        else
            echo -e "${YELLOW}⚠ Nie można pobrać listy modeli${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Serwer Ollama nie jest jeszcze dostępny pod adresem: http://localhost:11434${NC}"
        echo -e "${YELLOW}Sprawdź logi, aby zobaczyć status uruchamiania:${NC}"
        echo -e "${YELLOW}$DOCKER_COMPOSE -f \"$COMPOSE_FILE\" logs ollama${NC}"
    fi

    echo -e "\n${BLUE}Aby wyświetlić logi kontenerów:${NC}"
    echo -e "${YELLOW}$DOCKER_COMPOSE -f \"$COMPOSE_FILE\" logs -f${NC}"

    echo -e "\n${BLUE}Aby zatrzymać kontenery:${NC}"
    echo -e "${YELLOW}$DOCKER_COMPOSE -f \"$COMPOSE_FILE\" down${NC}"
}

# Główna funkcja
main() {
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${BLUE}   Uruchamianie Ollama API w Docker   ${NC}"
    echo -e "${BLUE}========================================================${NC}"

    # Sprawdzenie wymagań
    check_docker
    if [ $? -ne 0 ]; then
        exit 1
    fi

    check_docker_compose
    if [ $? -ne 0 ]; then
        exit 1
    fi

    check_docker_files
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Domyślny model
    MODEL_NAME="tinyllama"

    # Próba odczytania modelu z pliku compose
    if [ -f "$COMPOSE_FILE" ]; then
        MODEL_FROM_FILE=$(grep 'MODEL_NAME=' "$COMPOSE_FILE" | head -n 1 | sed -E 's/.*MODEL_NAME=([^:]+):?.*/\1/')
        if [ -n "$MODEL_FROM_FILE" ]; then
            MODEL_NAME="$MODEL_FROM_FILE"
        fi
    fi

    # Sprawdzenie dostępności modelu
    check_model_availability "$MODEL_NAME"

    # Uruchomienie kontenerów
    start_containers
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Wyświetlenie informacji
    show_info
}

# Uruchomienie głównej funkcji
main