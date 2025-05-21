#!/bin/bash

# Skrypt startowy - instaluje wszystko i uruchamia kompletne środowisko
# Autor: Tom
# Data: 2025-05-20

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}=== Uruchamianie środowiska Ollama z wyborem modeli ===${NC}"

# Lista wymaganych plików
required_files=(
  "models.sh"
  "env_loader.py"
  "server.py"
  "ask.sh"
)

# Funkcja do sprawdzania czy wszystkie pliki istnieją
check_files() {
  missing_files=()

  for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
      missing_files+=("$file")
    fi
  done

  if [ ${#missing_files[@]} -gt 0 ]; then
    echo -e "${RED}Błąd: Brakuje następujących plików:${NC}"
    for file in "${missing_files[@]}"; do
      echo -e "  - $file"
    done
    return 1
  fi

  return 0
}

# Sprawdzenie czy Python jest zainstalowany
check_python() {
  if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Błąd: Python 3 nie jest zainstalowany${NC}"
    echo -e "${YELLOW}Zainstaluj Python 3 ze strony: https://www.python.org/downloads/${NC}"
    return 1
  fi

  return 0
}

# Instalacja wymaganych pakietów Python
install_packages() {
  echo -e "${BLUE}Instalacja wymaganych pakietów Python...${NC}"

  # Lista wymaganych pakietów
  required_packages=("flask" "requests" "python-dotenv")

  # Sprawdzenie zainstalowanych pakietów
  installed_packages=$(pip list 2>/dev/null | awk '{print $1}' | tr '[:upper:]' '[:lower:]')

  # Filtrowanie pakietów, które trzeba zainstalować
  packages_to_install=()
  for package in "${required_packages[@]}"; do
    if ! echo "$installed_packages" | grep -q "^$(echo "$package" | tr '[:upper:]' '[:lower:]')$"; then
      packages_to_install+=("$package")
    fi
  done

  # Instalacja brakujących pakietów
  if [ ${#packages_to_install[@]} -gt 0 ]; then
    echo -e "${YELLOW}Instalacja pakietów: ${packages_to_install[*]}${NC}"
    pip install "${packages_to_install[@]}"

    if [ $? -ne 0 ]; then
      echo -e "${RED}Błąd podczas instalacji pakietów${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}Wszystkie wymagane pakiety są już zainstalowane${NC}"
  fi

  return 0
}

# Nadanie uprawnień wykonywania skryptom
set_permissions() {
  echo -e "${BLUE}Nadawanie uprawnień wykonywania skryptom...${NC}"

  chmod +x models.sh
  chmod +x ask.sh

  return 0
}

# Konfiguracja Ollama i modeli
configure_ollama() {
  echo -e "${BLUE}Konfiguracja Ollama i modeli...${NC}"

  ./models.sh

  if [ $? -ne 0 ]; then
    echo -e "${RED}Błąd podczas konfiguracji Ollama${NC}"
    return 1
  fi

  return 0
}

# Uruchomienie serwera
run_server() {
  echo -e "${BLUE}Uruchamianie serwera...${NC}"

  # Pobranie portu z pliku .env
  SERVER_PORT=5001
  if [ -f ".env" ]; then
    PORT_FROM_ENV=$(grep "^SERVER_PORT=" .env | cut -d'=' -f2)
    if [ ! -z "$PORT_FROM_ENV" ]; then
      SERVER_PORT=$PORT_FROM_ENV
    fi
  fi

  echo -e "${GREEN}Serwer będzie dostępny pod adresem:${NC} http://localhost:${SERVER_PORT}"
  echo -e "${YELLOW}Naciśnij Ctrl+C aby zatrzymać serwer${NC}"

  python server.py

  return $?
}

# Główna funkcja
main() {
  # Sprawdzenie plików
  check_files
  if [ $? -ne 0 ]; then
    echo -e "${RED}Instalacja przerwana z powodu brakujących plików${NC}"
    exit 1
  fi

  # Sprawdzenie Pythona
  check_python
  if [ $? -ne 0 ]; then
    echo -e "${RED}Instalacja przerwana z powodu braku Pythona${NC}"
    exit 1
  fi

  # Instalacja pakietów
  install_packages
  if [ $? -ne 0 ]; then
    echo -e "${RED}Instalacja przerwana z powodu błędu podczas instalacji pakietów${NC}"
    exit 1
  fi

  # Nadanie uprawnień
  set_permissions

  # Konfiguracja Ollama
  configure_ollama
  if [ $? -ne 0 ]; then
    echo -e "${RED}Instalacja przerwana z powodu błędu podczas konfiguracji Ollama${NC}"
    exit 1
  fi

  # Uruchomienie serwera
  run_server

  return $?
}

# Uruchomienie głównej funkcji
main