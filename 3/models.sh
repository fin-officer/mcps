#!/bin/bash

# Skrypt do zarządzania modelami Ollama
# Autor: Tom
# Data: 2025-05-20

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Domyślne wartości
DEFAULT_MODEL="tinyllama:latest"
ENV_FILE=".env"
MODELS_LIST="models.txt"
OLLAMA_URL="http://localhost:11434"


# Funkcja do sprawdzania czy Ollama jest dostępna
check_ollama() {
  if ! command -v ollama &> /dev/null; then
    echo -e "${RED}Błąd: Ollama nie jest zainstalowana${NC}"
    echo -e "${YELLOW}Możesz ją zainstalować ze strony: https://ollama.com/download${NC}"
    return 1
  fi

  if ! curl -s --head --connect-timeout 2 $OLLAMA_URL > /dev/null; then
    echo -e "${RED}Błąd: Serwer Ollama nie jest uruchomiony${NC}"
    echo -e "${YELLOW}Uruchom w nowym terminalu: ollama serve${NC}"

    # Pytanie czy chcesz uruchomić Ollama
    read -p "Czy chcesz uruchomić serwer Ollama teraz? (t/n): " start_ollama
    if [[ "$start_ollama" == "t" ]]; then
      echo -e "${BLUE}Uruchamianie serwera Ollama w nowym terminalu...${NC}"

      # Próba otwarcia nowego terminala z serwerem Ollama
      gnome-terminal -- bash -c "ollama serve; read -p 'Naciśnij Enter, aby zamknąć...'" || \
      xterm -e "ollama serve; read -p 'Naciśnij Enter, aby zamknąć...'" || \
      konsole --new-tab -e "ollama serve; read -p 'Naciśnij Enter, aby zamknąć...'" || \
      (
        echo -e "${RED}Nie udało się uruchomić nowego terminala${NC}"
        echo -e "${YELLOW}Uruchom Ollama ręcznie w nowym terminalu komendą:${NC} ollama serve"
        return 1
      )

      # Czekanie aż serwer będzie dostępny
      echo -e "${BLUE}Czekanie na uruchomienie serwera Ollama...${NC}"
      for i in {1..10}; do
        if curl -s --head --connect-timeout 2 $OLLAMA_URL > /dev/null; then
          echo -e "${GREEN}Serwer Ollama został uruchomiony!${NC}"
          return 0
        fi
        echo -n "."
        sleep 1
      done

      echo -e "${RED}Timeout: Nie udało się uruchomić serwera Ollama${NC}"
      return 1
    else
      return 1
    fi
  fi

  return 0
}

# Funkcja do pobierania listy modeli Ollama
fetch_models() {
  echo -e "${BLUE}Pobieranie listy popularnych modeli Ollama...${NC}"

  # Popularne małe modele, które dobrze działają lokalnie
  cat > $MODELS_LIST << 'EOL'
tinyllama:latest|TinyLLama (1.1B) - Mały, szybki model ogólnego zastosowania
llama2:latest|Llama 2 (7B) - Podstawowy model od Meta
phi:latest|Microsoft Phi-2 (2.7B) - Mały model ze świetnymi możliwościami rozumowania
gemma:latest|Google Gemma (2B) - Mały model od Google
gemma:7b|Google Gemma (7B) - Większa wersja modelu Gemma
mistral:latest|Mistral (7B) - Bardzo dobry model open-source
qwen:latest|Qwen (1.8B) - Efektywny i zbalansowany model od Alibaba
qwen:7b|Qwen (7B) - Większa wersja modelu Qwen
codegemma:latest|CodeGemma (2B) - Mały model od Google do generowania kodu
codellama:latest|Code Llama (7B) - Model od Meta do generowania kodu
stablelm:latest|StableLM (3B) - Kompaktowy model od Stability AI
orca-mini:latest|Orca Mini (3B) - Mały model trenowany do udzielania pomocnych odpowiedzi
neural-chat:latest|Neural Chat (7B) - Model konwersacyjny o przyjaznych odpowiedziach
vicuna:latest|Vicuna (7B) - Popularny model konwersacyjny
EOL

  # Sortowanie modeli alfabetycznie
  sort -o $MODELS_LIST $MODELS_LIST

  echo -e "${GREEN}Lista ${BOLD}$(wc -l < $MODELS_LIST)${NC}${GREEN} modeli została zapisana do pliku $MODELS_LIST${NC}"
}

# Funkcja do tworzenia pliku .env
create_env_file() {
  local selected_model=$1

  echo -e "${BLUE}Tworzenie pliku $ENV_FILE z wybranym modelem...${NC}"

  # Sprawdzenie czy plik .env już istnieje
  if [ -f "$ENV_FILE" ]; then
    # Aktualizacja istniejącego pliku
    if grep -q "^MODEL_NAME=" "$ENV_FILE"; then
      sed -i "s/^MODEL_NAME=.*/MODEL_NAME=\"$selected_model\"/" "$ENV_FILE"
    else
      echo "MODEL_NAME=\"$selected_model\"" >> "$ENV_FILE"
    fi
  else
    # Tworzenie nowego pliku .env
    cat > $ENV_FILE << EOL
# Konfiguracja modelu Ollama
MODEL_NAME="$selected_model"

# Konfiguracja serwera
OLLAMA_URL="http://localhost:11434"
SERVER_PORT=5001

# Parametry generowania
TEMPERATURE=0.7
MAX_TOKENS=1000
EOL
  fi

  echo -e "${GREEN}Plik $ENV_FILE został zaktualizowany z wybranym modelem: ${BOLD}$selected_model${NC}"
}

# Funkcja do pobrania modelu
download_model() {
  local model=$1

  echo -e "${BLUE}Pobieranie modelu: $model${NC}"
  echo -e "${YELLOW}To może zająć kilka minut, w zależności od rozmiaru modelu i prędkości internetu...${NC}"

  # Pobieranie modelu za pomocą Ollama
  ollama pull "$model"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Model $model został pomyślnie pobrany!${NC}"
    return 0
  else
    echo -e "${RED}Błąd podczas pobierania modelu $model${NC}"
    return 1
  fi
}

# Funkcja do wyświetlania dostępnych i zainstalowanych modeli
show_models() {
  echo -e "\n${BLUE}${BOLD}=== Dostępne modele Ollama ===${NC}\n"

  # Pobieranie listy zainstalowanych modeli
  local installed_models=$(ollama list 2>/dev/null | awk '{print $1}')

  # Pobieranie listy dostępnych modeli
  if [ ! -f "$MODELS_LIST" ]; then
    fetch_models
  fi

  # Wyświetlanie modeli z informacją o instalacji
  echo -e "${BOLD}ID | Model | Status | Opis${NC}"
  echo "------------------------------------------------------------------------------------"

  local id=1
  while IFS="|" read -r model description; do
    # Sprawdzenie czy model jest zainstalowany
    if echo "$installed_models" | grep -q "$model"; then
      status="${GREEN}✓ ZAINSTALOWANY${NC}"
    else
      status="${YELLOW}DOSTĘPNY${NC}"
    fi

    # Wyświetlenie informacji o modelu
    echo -e "${CYAN}$id${NC} | ${BOLD}$model${NC} | $status | $description"
    id=$((id+1))
  done < $MODELS_LIST

  echo "------------------------------------------------------------------------------------"
}

# Funkcja do wyboru modelu
select_model() {
  local selection=""
  local model=""

  # Wyświetlenie dostępnych modeli
  show_models

  echo -e "\nWybierz model do pobrania/użycia:"
  echo -e "  - Wpisz numer ID aby wybrać model z listy"
  echo -e "  - Wpisz nazwę modelu ręcznie (np. tinyllama:latest)"
  echo -e "  - Wciśnij Enter aby użyć domyślnego (${BOLD}$DEFAULT_MODEL${NC})"

  # Wybór modelu
  read -p "Twój wybór: " selection

  # Jeśli użytkownik nie podał nic, użyj domyślnego modelu
  if [ -z "$selection" ]; then
    model="$DEFAULT_MODEL"
    echo -e "${BLUE}Wybrano domyślny model: ${BOLD}$model${NC}"
  # Jeśli użytkownik podał numer, pobierz model z listy
  elif [[ "$selection" =~ ^[0-9]+$ ]]; then
    model=$(sed -n "${selection}p" $MODELS_LIST | cut -d'|' -f1)

    if [ -z "$model" ]; then
      echo -e "${RED}Błąd: Nieprawidłowy numer modelu${NC}"
      return 1
    fi

    echo -e "${BLUE}Wybrano model #$selection: ${BOLD}$model${NC}"
  # Jeśli użytkownik podał nazwę, użyj jej bezpośrednio
  else
    model="$selection"
    echo -e "${BLUE}Wybrano model: ${BOLD}$model${NC}"
  fi

  # Sprawdzenie czy model jest już zainstalowany
  if ollama list 2>/dev/null | awk '{print $1}' | grep -q "^$model$"; then
    echo -e "${GREEN}Model $model jest już zainstalowany${NC}"
  else
    # Pytanie czy chcesz pobrać model
    read -p "Model $model nie jest zainstalowany. Czy chcesz go pobrać? (t/n): " download_choice
    if [[ "$download_choice" == "t" ]]; then
      download_model "$model"
      if [ $? -ne 0 ]; then
        return 1
      fi
    else
      echo -e "${YELLOW}Model nie został pobrany. Nadal możesz go użyć, ale będzie musiał zostać pobrany później.${NC}"
    fi
  fi

  # Zapisz wybrany model do pliku .env
  create_env_file "$model"

  return 0
}

# Funkcja do aktualizacji pliku konfiguracyjnego serwera
update_server_config() {
  local model=$1
  local server_file="server4.py"

  if [ -f "$server_file" ]; then
    echo -e "${BLUE}Aktualizacja konfiguracji serwera w pliku $server_file...${NC}"

    # Zmiana modelu w pliku serwera
    sed -i "s/MODEL_NAME = \"[^\"]*\"/MODEL_NAME = \"$model\"/" "$server_file"

    echo -e "${GREEN}Plik $server_file został zaktualizowany z nowym modelem: ${BOLD}$model${NC}"
  else
    echo -e "${YELLOW}Plik $server_file nie istnieje. Tylko plik .env został zaktualizowany.${NC}"
  fi
}

# Główna funkcja
main() {
  echo -e "${BLUE}${BOLD}=== Konfiguracja modeli Ollama ===${NC}"

  # Sprawdzenie czy Ollama jest dostępna
  check_ollama
  if [ $? -ne 0 ]; then
    exit 1
  fi

  # Pobieranie listy dostępnych modeli
  if [ ! -f "$MODELS_LIST" ]; then
    fetch_models
  fi

  # Wybór modelu
  select_model
  if [ $? -ne 0 ]; then
    exit 1
  fi

  # Pobieranie nazwy wybranego modelu z pliku .env
  if [ -f "$ENV_FILE" ]; then
    selected_model=$(grep "^MODEL_NAME=" "$ENV_FILE" | cut -d'"' -f2)

    # Aktualizacja pliku konfiguracyjnego serwera
    update_server_config "$selected_model"

    echo -e "\n${GREEN}${BOLD}Konfiguracja zakończona pomyślnie!${NC}"
    echo -e "Model ${BOLD}$selected_model${NC} został skonfigurowany jako domyślny."
    echo -e "Parametry zostały zapisane w pliku ${BOLD}$ENV_FILE${NC}"

    # Wskazówki jak używać
    echo -e "\n${BLUE}Aby użyć skonfigurowanego modelu:${NC}"
    echo -e "1. Uruchom serwer: ${BOLD}python server4.py${NC}"
    echo -e "2. Zadawaj pytania: ${BOLD}./ask3.sh \"Twoje pytanie\"${NC}"
  else
    echo -e "${RED}Błąd: Plik $ENV_FILE nie został utworzony${NC}"
    exit 1
  fi
}

# Wywołanie głównej funkcji
main