#!/bin/bash

# Prosty skrypt do zadawania pytań do TinyLLM via Ollama
# Autor: Tom
# Data: 2025-05-20

# Kolory
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Domyślne wartości
SERVER_URL="http://localhost:5001"
TIMEOUT=60

# Sprawdzenie argumentów
if [ $# -eq 0 ]; then
    echo -e "${RED}Błąd: Brak pytania${NC}"
    echo -e "${YELLOW}Użycie: $0 \"Twoje pytanie\"${NC}"
    exit 1
fi

# Przygotowanie pytania (escapowanie cudzysłowów)
PROMPT=$(echo "$1" | sed 's/"/\\"/g')
echo -e "${BLUE}Pytanie:${NC} $1"

# Bezpośrednie zapytanie do Ollama (pomija serwer Flask)
if [ "$2" == "--direct" ]; then
    echo -e "${YELLOW}Zapytanie bezpośrednio do Ollama...${NC}"

    # Sprawdzenie czy Ollama jest uruchomiona
    if ! curl -s --head --connect-timeout 2 http://localhost:11434 > /dev/null; then
        echo -e "${RED}Błąd: Serwer Ollama nie jest uruchomiony.${NC}"
        echo -e "${YELLOW}Uruchom w nowym terminalu: ollama serve${NC}"
        exit 1
    fi

    echo -e "${BLUE}Oczekiwanie na odpowiedź...${NC}"
    curl -s -X POST http://localhost:11434/api/generate \
         -d "{\"model\":\"tinyllama\",\"prompt\":\"$PROMPT\",\"stream\":false}" | jq -r '.response'
    exit 0
fi

# Zapytanie do serwera Flask
echo -e "${YELLOW}Wysyłanie zapytania do serwera...${NC}"
JSON="{\"prompt\":\"$PROMPT\"}"

# Sprawdzenie czy serwer jest dostępny
if ! curl -s --head --connect-timeout 2 $SERVER_URL > /dev/null; then
    echo -e "${RED}Błąd: Serwer nie jest dostępny (${SERVER_URL}).${NC}"
    echo -e "${YELLOW}Uruchom w nowym terminalu: python server4.py${NC}"

    # Zapytanie czy użytkownik chce spróbować bezpośrednio z Ollama
    read -p "Czy chcesz spróbować zapytać bezpośrednio Ollama? (t/n): " try_ollama
    if [ "$try_ollama" == "t" ]; then
        echo -e "${YELLOW}Zapytanie bezpośrednio do Ollama...${NC}"

        # Sprawdzenie czy Ollama jest uruchomiona
        if ! curl -s --head --connect-timeout 2 http://localhost:11434 > /dev/null; then
            echo -e "${RED}Błąd: Serwer Ollama nie jest uruchomiony.${NC}"
            echo -e "${YELLOW}Uruchom w nowym terminalu: ollama serve${NC}"
            exit 1
        fi

        echo -e "${BLUE}Oczekiwanie na odpowiedź...${NC}"
        curl -s -X POST http://localhost:11434/api/generate \
             -d "{\"model\":\"tinyllama\",\"prompt\":\"$PROMPT\",\"stream\":false}" | jq -r '.response'
        exit 0
    else
        exit 1
    fi
fi

# Wysłanie zapytania i wyświetlenie odpowiedzi
echo -e "${BLUE}Oczekiwanie na odpowiedź...${NC}"
curl -s -m $TIMEOUT -X POST -H "Content-Type: application/json" \
     -d "$JSON" \
     $SERVER_URL/ask > response.json

# Sprawdzenie czy odpowiedź jest poprawna
if [ $? -ne 0 ]; then
    echo -e "${RED}Błąd: Nie udało się uzyskać odpowiedzi (timeout: ${TIMEOUT}s)${NC}"
    echo -e "${YELLOW}Spróbuj bezpośrednio: $0 \"$1\" --direct${NC}"
    exit 1
fi

# Wyświetlenie odpowiedzi
echo -e "\n${GREEN}Odpowiedź:${NC}"
echo "---------------------------------------------------------"
cat response.json | jq -r '.response // .error // "Błąd: Nieoczekiwany format odpowiedzi"'
echo "---------------------------------------------------------"

# Usunięcie pliku tymczasowego
rm -f response.json