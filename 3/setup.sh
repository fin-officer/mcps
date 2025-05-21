#!/bin/bash
# Skrypt instalacyjny do przygotowania środowiska dla server.py
# Działa niezależnie od platformy i nie tworzy dodatkowych plików

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

echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE}   Przygotowanie środowiska dla Ollama API (server.py)   ${NC}"
echo -e "${BLUE}========================================================${NC}"

# Sprawdzenie czy Python jest zainstalowany
check_python() {
    echo -e "${BLUE}Sprawdzanie instalacji Pythona...${NC}"
    if command -v python3 &> /dev/null; then
        PYTHON="python3"
        echo -e "${GREEN}✓ Python 3 znaleziony${NC}"
    elif command -v python &> /dev/null; then
        # Sprawdzenie wersji
        PYTHON_VERSION=$(python --version 2>&1)
        if [[ $PYTHON_VERSION == *"Python 3"* ]]; then
            PYTHON="python"
            echo -e "${GREEN}✓ Python 3 znaleziony${NC}"
        else
            echo -e "${RED}✗ Znaleziono Python $(python --version 2>&1), ale wymagany jest Python 3${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Python 3 nie jest zainstalowany${NC}"
        echo -e "${YELLOW}Proszę zainstalować Python 3 ze strony: https://www.python.org/downloads/${NC}"
        return 1
    fi
    return 0
}

# Sprawdzenie czy pip jest zainstalowany
check_pip() {
    echo -e "${BLUE}Sprawdzanie instalacji pip...${NC}"
    if $PYTHON -m pip --version &> /dev/null; then
        echo -e "${GREEN}✓ pip znaleziony${NC}"
        return 0
    else
        echo -e "${RED}✗ pip nie jest zainstalowany${NC}"
        echo -e "${YELLOW}Instalowanie pip...${NC}"

        # Próba instalacji pip (różnie w zależności od systemu)
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            sudo apt-get update
            sudo apt-get install -y python3-pip
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL
            sudo yum install -y python3-pip
        elif command -v dnf &> /dev/null; then
            # Fedora
            sudo dnf install -y python3-pip
        elif command -v pacman &> /dev/null; then
            # Arch Linux
            sudo pacman -S python-pip
        elif command -v brew &> /dev/null; then
            # macOS z Homebrew
            brew install python3
        else
            # Próba instalacji pip za pomocą get-pip.py
            echo -e "${YELLOW}Próba instalacji pip za pomocą get-pip.py...${NC}"
            curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py
            $PYTHON get-pip.py
            rm get-pip.py
        fi

        # Sprawdzenie czy pip został zainstalowany
        if $PYTHON -m pip --version &> /dev/null; then
            echo -e "${GREEN}✓ pip został zainstalowany${NC}"
            return 0
        else
            echo -e "${RED}✗ Nie udało się zainstalować pip${NC}"
            echo -e "${YELLOW}Proszę zainstalować pip ręcznie: https://pip.pypa.io/en/stable/installation/${NC}"
            return 1
        fi
    fi
}

# Sprawdzenie czy Ollama jest zainstalowana
check_ollama() {
    echo -e "${BLUE}Sprawdzanie instalacji Ollama...${NC}"
    if command -v ollama &> /dev/null; then
        echo -e "${GREEN}✓ Ollama znaleziona${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Ollama nie jest zainstalowana${NC}"
        echo -e "${YELLOW}Ollama jest wymagana do działania serwera${NC}"
        echo -e "${YELLOW}Pobierz Ollama ze strony: https://ollama.com/download${NC}"
        echo -e "${YELLOW}i zainstaluj zgodnie z instrukcjami dla Twojego systemu${NC}"

        # Pytanie czy kontynuować mimo braku Ollama
        read -p "Czy chcesz kontynuować instalację mimo braku Ollama? (t/n): " continue_choice
        if [[ "$continue_choice" == "t" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Instalacja wymaganych pakietów Python
install_packages() {
    echo -e "${BLUE}Instalacja wymaganych pakietów Python...${NC}"

    # Lista wymaganych pakietów
    PACKAGES=("flask" "requests" "python-dotenv")

    # Instalacja pakietów
    echo -e "${YELLOW}Instalacja: ${PACKAGES[*]}${NC}"
    $PYTHON -m pip install --user ${PACKAGES[@]}

    # Sprawdzenie czy wszystkie pakiety zostały zainstalowane
    MISSING=()
    for package in "${PACKAGES[@]}"; do
        if ! $PYTHON -c "import $package" &> /dev/null; then
            MISSING+=("$package")
        fi
    done

    if [ ${#MISSING[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ Wszystkie pakiety zostały zainstalowane pomyślnie${NC}"
        return 0
    else
        echo -e "${RED}✗ Nie udało się zainstalować następujących pakietów: ${MISSING[*]}${NC}"
        echo -e "${YELLOW}Spróbuj zainstalować je ręcznie: $PYTHON -m pip install ${MISSING[*]}${NC}"
        return 1
    fi
}

# Główna funkcja
main() {
    # Sprawdzenie czy Python jest zainstalowany
    check_python
    if [ $? -ne 0 ]; then
        echo -e "${RED}Przygotowanie środowiska nie powiodło się: Brak Pythona 3${NC}"
        exit 1
    fi

    # Sprawdzenie czy pip jest zainstalowany
    check_pip
    if [ $? -ne 0 ]; then
        echo -e "${RED}Przygotowanie środowiska nie powiodło się: Brak pip${NC}"
        exit 1
    fi

    # Sprawdzenie czy Ollama jest zainstalowana
    check_ollama
    if [ $? -ne 0 ]; then
        echo -e "${RED}Przygotowanie środowiska nie powiodło się: Brak Ollama${NC}"
        exit 1
    fi

    # Instalacja wymaganych pakietów
    install_packages
    if [ $? -ne 0 ]; then
        echo -e "${RED}Przygotowanie środowiska nie powiodło się: Błąd instalacji pakietów${NC}"
        exit 1
    fi

    # Sprawdzenie czy server.py istnieje
    if [ ! -f "server.py" ]; then
        echo -e "${YELLOW}⚠ Plik server.py nie został znaleziony w bieżącym katalogu${NC}"
        echo -e "${YELLOW}Upewnij się, że plik server.py znajduje się w tym samym katalogu co skrypt setup_env.sh${NC}"
    fi

    # Zakończenie
    echo -e "${GREEN}========================================================${NC}"
    echo -e "${GREEN}   Środowisko zostało pomyślnie przygotowane!   ${NC}"
    echo -e "${GREEN}========================================================${NC}"
    echo -e ""
    echo -e "${BLUE}Aby uruchomić serwer:${NC}"
    echo -e "${YELLOW}$PYTHON server.py${NC}"
    echo -e ""
    echo -e "${BLUE}Serwer będzie dostępny pod adresem:${NC}"
    echo -e "${YELLOW}http://localhost:5001${NC}"
    echo -e ""
    echo -e "${BLUE}Jeśli chcesz zmienić port, utwórz plik .env z zawartością:${NC}"
    echo -e "${YELLOW}SERVER_PORT=8080${NC}"

    # Pytanie czy uruchomić serwer od razu
    echo -e ""
    read -p "Czy chcesz uruchomić serwer teraz? (t/n): " run_server
    if [[ "$run_server" == "t" ]]; then
        echo -e "${BLUE}Uruchamianie serwera...${NC}"
        echo -e "${YELLOW}Naciśnij Ctrl+C aby zatrzymać serwer${NC}"
        $PYTHON server.py
    else
        echo -e "${BLUE}Możesz uruchomić serwer później komendą:${NC} $PYTHON server.py"
    fi
}

# Uruchomienie głównej funkcji
main