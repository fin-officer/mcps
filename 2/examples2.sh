#!/bin/bash

# Przykłady poprawnych zapytań curl do serwera TinyLLM

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Przykłady zapytań curl do TinyLLM     ${NC}"
echo -e "${BLUE}========================================${NC}"

# Test echo
echo -e "${YELLOW}Test echo:${NC}"
curl -s -X POST -H "Content-Type: application/json" \
     -d '{"message":"Test"}' \
     http://localhost:5000/echo | jq '.'

echo -e "\n${YELLOW}Zapytanie do TinyLLM:${NC}"
# Zapytanie w jednej linii (działa)
curl -s -X POST -H "Content-Type: application/json" -d '{"prompt":"Co to jest Python?"}' http://localhost:5000/ask | jq '.'

echo -e "\n${YELLOW}Alternatywna metoda (z echo):${NC}"
# Alternatywne zapytanie z echo
echo '{"prompt":"Co to jest Python?"}' | curl -s -X POST -H "Content-Type: application/json" -d @- http://localhost:5000/ask | jq '.'

echo -e "\n${YELLOW}Alternatywna metoda (z zmiennej):${NC}"
# Alternatywne zapytanie z zmiennej
JSON='{"prompt":"Co to jest sztuczna inteligencja?"}'
curl -s -X POST -H "Content-Type: application/json" -d "$JSON" http://localhost:5000/ask | jq '.'

echo -e "\n${GREEN}Wszystkie metody powinny działać poprawnie.${NC}"
echo -e "${GREEN}Jeśli któraś z nich nie działa, spróbuj innych.${NC}"