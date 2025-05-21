#!/bin/bash
# =========================================================================
# Uniwersalny skrypt do konfiguracji i uruchomienia środowiska Ollama
# Działa niezależnie od dystrybucji Linux, macOS i innych systemów Unix
# Połączenie funkcjonalności z setup.sh, start.sh i ollama.sh
# Data: 2025-05-21
# =========================================================================

# Kolory dla lepszej czytelności
if [[ -t 1 ]]; then  # Sprawdzenie czy terminal obsługuje kolory
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'  # No Color
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Zmienne globalne
PYTHON="python3"
OLLAMA_PID=""
SERVER_PORT=5001
REQUIRED_PACKAGES=("flask" "requests" "python-dotenv")
MODELS_LOADED=false

# Funkcja do wyświetlania pomocy
show_help() {
    echo -e "${BLUE}${BOLD}Uniwersalny skrypt do konfiguracji i uruchomienia środowiska Ollama${NC}"
    echo ""
    echo -e "${YELLOW}Użycie:${NC}"
    echo -e "  $0 [opcje]"
    echo ""
    echo -e "${YELLOW}Opcje:${NC}"
    echo -e "  -h, --help           Wyświetla tę pomoc"
    echo -e "  -s, --setup          Tylko konfiguracja środowiska (bez uruchamiania)"
    echo -e "  -r, --run            Uruchomienie serwera (bez ponownej konfiguracji)"
    echo -e "  -p, --port PORT      Ustawienie niestandardowego portu (domyślnie: 5001)"
    echo -e "  -m, --models         Konfiguracja modeli Ollama"
    echo -e "  -c, --check          Sprawdzenie wymagań systemowych"
    echo ""
    echo -e "${YELLOW}Przykłady:${NC}"
    echo -e "  $0                   Pełna konfiguracja i uruchomienie serwera"
    echo -e "  $0 --setup           Tylko konfiguracja środowiska"
    echo -e "  $0 --run --port 8080 Uruchomienie serwera na porcie 8080"
}

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

# Funkcja do logowania
log() {
    local level=$1
    local message=$2

    case $level in
        "info")
            echo -e "${BLUE}[INFO] $message${NC}"
            ;;
        "success")
            echo -e "${GREEN}[OK] $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}[UWAGA] $message${NC}"
            ;;
        "error")
            echo -e "${RED}[BŁĄD] $message${NC}"
            ;;
    esac
}

# Funkcja do sprawdzania czy Python jest zainstalowany
check_python() {
    log "info" "Sprawdzanie instalacji Pythona..."

    if command -v python3 &> /dev/null; then
        PYTHON="python3"
        local python_version=$($PYTHON --version 2>&1)
        log "success" "Python 3 znaleziony ($python_version)"
    elif command -v python &> /dev/null; then
        # Sprawdzenie wersji
        local python_version=$(python --version 2>&1)
        if [[ $python_version == *"Python 3"* ]]; then
            PYTHON="python"
            log "success" "Python 3 znaleziony ($python_version)"
        else
            log "error" "Znaleziono $python_version, ale wymagany jest Python 3"
            return 1
        fi
    else
        log "error" "Python 3 nie jest zainstalowany"
        log "warning" "Zainstaluj Python 3 ze strony: https://www.python.org/downloads/"
        return 1
    fi
    return 0
}

# Sprawdzenie czy pip jest zainstalowany
check_pip() {
    log "info" "Sprawdzanie instalacji pip..."

    if $PYTHON -m pip --version &> /dev/null; then
        local pip_version=$($PYTHON -m pip --version)
        log "success" "pip znaleziony ($pip_version)"
        return 0
    else
        log "warning" "pip nie jest zainstalowany"
        log "info" "Próba instalacji pip..."

        # Próba instalacji pip (różnie w zależności od systemu)
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            log "info" "Wykryto system bazujący na Debian/Ubuntu, używam apt-get..."
            sudo apt-get update
            sudo apt-get install -y python3-pip
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL
            log "info" "Wykryto system bazujący na CentOS/RHEL, używam yum..."
            sudo yum install -y python3-pip
        elif command -v dnf &> /dev/null; then
            # Fedora
            log "info" "Wykryto system bazujący na Fedora, używam dnf..."
            sudo dnf install -y python3-pip
        elif command -v pacman &> /dev/null; then
            # Arch Linux
            log "info" "Wykryto system bazujący na Arch Linux, używam pacman..."
            sudo pacman -S python-pip
        elif command -v brew &> /dev/null; then
            # macOS z Homebrew
            log "info" "Wykryto macOS z Homebrew, używam brew..."
            brew install python3
        elif command -v zypper &> /dev/null; then
            # openSUSE
            log "info" "Wykryto system openSUSE, używam zypper..."
            sudo zypper install python3-pip
        elif command -v apk &> /dev/null; then
            # Alpine Linux
            log "info" "Wykryto system Alpine Linux, używam apk..."
            apk add python3-pip
        else
            # Próba instalacji pip za pomocą get-pip.py
            log "info" "Nie wykryto standardowego menedżera pakietów, próba instalacji pip za pomocą get-pip.py..."
            curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py
            $PYTHON get-pip.py
            rm get-pip.py
        fi

        # Sprawdzenie czy pip został zainstalowany
        if $PYTHON -m pip --version &> /dev/null; then
            local pip_version=$($PYTHON -m pip --version)
            log "success" "pip został zainstalowany ($pip_version)"
            return 0
        else
            log "error" "Nie udało się zainstalować pip"
            log "warning" "Zainstaluj pip ręcznie: https://pip.pypa.io/en/stable/installation/"

            # Daj użytkownikowi wybór czy kontynuować bez pip
            read -p "Czy chcesz kontynuować mimo braku pip? (t/n): " continue_choice
            if [[ "$continue_choice" == "t" || "$continue_choice" == "T" ]]; then
                log "warning" "Kontynuowanie bez pip..."
                return 0
            else
                return 1
            fi
        fi
    fi
}

# Sprawdzenie czy Ollama jest zainstalowana
check_ollama() {
    log "info" "Sprawdzanie instalacji Ollama..."

    if command -v ollama &> /dev/null; then
        log "success" "Ollama znaleziona"
        return 0
    else
        log "warning" "Ollama nie jest zainstalowana"
        log "warning" "Ollama jest wymagana do działania serwera"
        log "warning" "Pobierz Ollama ze strony: https://ollama.com/download"
        log "warning" "i zainstaluj zgodnie z instrukcjami dla Twojego systemu"

        # Pytanie czy kontynuować mimo braku Ollama
        read -p "Czy chcesz kontynuować instalację mimo braku Ollama? (t/n): " continue_choice
        if [[ "$continue_choice" == "t" || "$continue_choice" == "T" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Instalacja wymaganych pakietów Python
install_packages() {
    log "info" "Instalacja wymaganych pakietów Python..."

    # Bezpośrednia instalacja pakietów zamiast wstępnego sprawdzania
    # To rozwiązuje problem z detekcją zainstalowanych pakietów
    log "info" "Instalacja pakietów: ${REQUIRED_PACKAGES[*]}"

    # Pierwsza próba - z opcją --user
    $PYTHON -m pip install --user --upgrade "${REQUIRED_PACKAGES[@]}" 2>/dev/null

    # Sprawdzenie kodu wyjścia
    if [ $? -ne 0 ]; then
        # Próba bez --user w przypadku błędu (np. w środowisku virtualenv)
        log "warning" "Próba instalacji bez opcji --user..."
        $PYTHON -m pip install --upgrade "${REQUIRED_PACKAGES[@]}"

        if [ $? -ne 0 ]; then
            log "error" "Błąd podczas instalacji pakietów"

            # Spróbujmy zainstalować każdy pakiet osobno
            log "warning" "Próba instalacji pakietów pojedynczo..."
            local failed_packages=()

            for package in "${REQUIRED_PACKAGES[@]}"; do
                log "info" "Instalacja pakietu: $package"
                $PYTHON -m pip install --upgrade "$package"

                if [ $? -ne 0 ]; then
                    failed_packages+=("$package")
                fi
            done

            if [ ${#failed_packages[@]} -gt 0 ]; then
                log "error" "Nie udało się zainstalować następujących pakietów: ${failed_packages[*]}"
                log "warning" "Spróbuj zainstalować je ręcznie: $PYTHON -m pip install ${failed_packages[*]}"
                return 1
            fi
        fi
    fi

    # Weryfikacja importów
    log "info" "Weryfikacja instalacji pakietów..."
    local missing=()

    # Flask
    if ! $PYTHON -c "import flask" &> /dev/null; then
        missing+=("flask")
    fi

    # Requests
    if ! $PYTHON -c "import requests" &> /dev/null; then
        missing+=("requests")
    fi

    # Python-dotenv (specjalna obsługa)
    # Pakiet nazywa się python-dotenv, ale importujemy dotenv
    if ! $PYTHON -c "import dotenv" &> /dev/null; then
        # Druga próba z inną nazwą modułu
        if ! $PYTHON -c "import os; import dotenv" &> /dev/null; then
            missing+=("python-dotenv")
        fi
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        log "success" "Wszystkie pakiety zostały zainstalowane pomyślnie"
        return 0
    else
        log "error" "Nie udało się zweryfikować następujących pakietów: ${missing[*]}"
        log "warning" "Problemy z importem. Spróbuj ręcznie: $PYTHON -m pip install --upgrade ${missing[*]}"

        # Interaktywne pytanie o kontynuację
        read -p "Czy chcesz kontynuować mimo problemów z pakietami? (t/n): " continue_choice
        if [[ "$continue_choice" == "t" || "$continue_choice" == "T" ]]; then
            log "warning" "Kontynuowanie pomimo problemów z pakietami..."
            return 0
        else
            return 1
        fi
    fi
}

# Sprawdzenie czy server.py istnieje
check_server_file() {
    log "info" "Sprawdzanie pliku server.py..."

    if [ -f "server.py" ]; then
        log "success" "Plik server.py znaleziony"
        return 0
    else
        log "error" "Plik server.py nie istnieje"
        log "warning" "Upewnij się, że plik server.py znajduje się w tym samym katalogu"
        return 1
    fi
}

# Funkcja do uruchomienia Ollama w tle
start_ollama() {
    log "info" "Uruchamianie serwera Ollama..."

    if ! command -v ollama &> /dev/null; then
        log "error" "Ollama nie jest zainstalowana"
        log "warning" "Pobierz Ollama ze strony: https://ollama.com/download"
        return 1
    fi

    # Sprawdzenie czy Ollama już działa
    if curl -s --head --connect-timeout 2 http://localhost:11434 &> /dev/null; then
        log "success" "Serwer Ollama już działa"
        return 0
    fi

    # Uruchomienie Ollamy w tle
    log "info" "Uruchamianie serwera Ollama w tle..."
    ollama serve > ollama.log 2>&1 &
    OLLAMA_PID=$!

    # Zapisanie PID do pliku
    echo $OLLAMA_PID > .ollama.pid

    # Czekanie na uruchomienie serwera
    echo -n "Czekanie na uruchomienie serwera Ollama"
    for i in {1..30}; do
        if curl -s --head --connect-timeout 1 http://localhost:11434 &> /dev/null; then
            echo ""
            log "success" "Serwer Ollama został uruchomiony!"
            return 0
        fi

        # Sprawdzenie czy proces nadal działa
        if ! is_process_running $OLLAMA_PID; then
            echo ""
            log "error" "Proces Ollama zakończył działanie nieoczekiwanie"
            log "warning" "Sprawdź plik ollama.log aby uzyskać więcej informacji"
            return 1
        fi

        echo -n "."
        sleep 1
    done

    echo ""
    log "error" "Timeout: Nie udało się uruchomić serwera Ollama w czasie 30 sekund"
    log "warning" "Sprawdź plik ollama.log aby uzyskać więcej informacji"
    return 1
}

# Funkcja do konfiguracji modeli Ollama
configure_models() {
    log "info" "Konfiguracja modeli Ollama..."

    if ! command -v ollama &> /dev/null; then
        log "error" "Ollama nie jest zainstalowana, nie można skonfigurować modeli"
        return 1
    fi

    # Sprawdzenie czy Ollama działa
    if ! curl -s --head --connect-timeout 2 http://localhost:11434 &> /dev/null; then
        log "warning" "Serwer Ollama nie działa, uruchamianie..."
        start_ollama
        if [ $? -ne 0 ]; then
            log "error" "Nie udało się uruchomić serwera Ollama"
            return 1
        fi
    fi

    # Lista dostępnych modeli
    log "info" "Pobieranie listy dostępnych modeli..."
    local available_models=$(curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*' | sed 's/"name":"//')

    # Wyświetlenie dostępnych modeli
    echo -e "${BLUE}Dostępne modele:${NC}"
    if [ -z "$available_models" ]; then
        echo -e "${YELLOW}Brak zainstalowanych modeli${NC}"
    else
        echo "$available_models" | nl -w2 -s") "
    fi

    # Pytanie, czy chcesz pobrać nowy model
    echo ""
    read -p "Czy chcesz pobrać nowy model? (t/n): " download_model
    if [[ "$download_model" == "t" || "$download_model" == "T" ]]; then
        echo -e "${BLUE}Popularne modele:${NC}"
        echo "1) llama3 - Najnowszy model Meta (8B parametrów) - ogólnego przeznaczenia, dobry do większości zadań"
        echo "2) phi3 - Model Microsoft (3.8B parametrów) - szybki, dobry do prostszych zadań, zoptymalizowany pod kątem kodu"
        echo "3) mistral - Dobry kompromis jakość/rozmiar (7B parametrów) - ogólnego przeznaczenia, efektywny energetycznie"
        echo "4) gemma - Model Google (7B parametrów) - dobry do zadań języka naturalnego i kreatywnego pisania"
        echo "5) tinyllama - Mały model (1.1B parametrów) - bardzo szybki, idealny dla słabszych urządzeń"
        echo "6) qwen - Model Alibaba Cloud (7-14B parametrów) - dobry w analizie tekstu, wsparcie dla języków azjatyckich"
        echo "7) llava - Model multimodalny z obsługą obrazów (7-13B parametrów) - pozwala na analizę obrazów i tekstu"
        echo "8) codellama - Wyspecjalizowany model do kodowania (7-34B parametrów) - świetny do generowania i analizy kodu"
        echo "9) vicuna - Modyfikacja LLaMa (7-13B parametrów) - wytrenowany na konwersacjach, dobry do dialogów"
        echo "10) falcon - Model TII (7-40B parametrów) - szybki i efektywny, dobry stosunek wydajności do rozmiaru"
        echo "11) orca-mini - Lekka wersja modelu Orca (3B parametrów) - dobry do podstawowych zadań NLP"
        echo "12) wizardcoder - Wyspecjalizowany dla programistów (13B parametrów) - stworzony do zadań związanych z kodem"
        echo "13) llama2 - Poprzednia generacja modelu Meta (7-70B parametrów) - sprawdzony w różnych zastosowaniach"
        echo "14) stablelm - Model Stability AI (3-7B parametrów) - dobry do generowania tekstu i dialogów"
        echo "15) dolphin - Dostrojony model konwersacyjny (7B parametrów) - koncentruje się na naturalności dialogów"
        echo "16) neural-chat - Model rozmów od Intel (7-13B parametrów) - zoptymalizowany pod kątem urządzeń Intel"
        echo "17) starling - Model optymalizowany pod kątem jakości odpowiedzi (7B parametrów) - mniejszy ale skuteczny"
        echo "18) openhermes - Model z naciskiem na postępowanie zgodnie z instrukcjami (7B parametrów) - dobra dokładność"
        echo "19) yi - Model 01.AI (6-34B parametrów) - zaawansowany model wielojęzyczny"
        echo "20) inny - Własny wybór modelu"

        read -p "Wybierz model do pobrania (1-20): " model_choice

        case $model_choice in
            1)
                model_name="llama3"
                model_size="8B"
                model_desc="ogólnego przeznaczenia, dobry do większości zadań"
                ;;
            2)
                model_name="phi3"
                model_size="3.8B"
                model_desc="szybki, dobry do prostszych zadań, zoptymalizowany pod kątem kodu"
                ;;
            3)
                model_name="mistral"
                model_size="7B"
                model_desc="ogólnego przeznaczenia, efektywny energetycznie"
                ;;
            4)
                model_name="gemma"
                model_size="7B"
                model_desc="dobry do zadań języka naturalnego i kreatywnego pisania"
                ;;
            5)
                model_name="tinyllama"
                model_size="1.1B"
                model_desc="bardzo szybki, idealny dla słabszych urządzeń"
                ;;
            6)
                model_name="qwen"
                model_size="7B"
                model_desc="dobry w analizie tekstu, wsparcie dla języków azjatyckich"
                ;;
            7)
                model_name="llava"
                model_size="7B"
                model_desc="multimodalny z obsługą obrazów"
                ;;
            8)
                model_name="codellama"
                model_size="7B"
                model_desc="wyspecjalizowany model do kodowania"
                ;;
            9)
                model_name="vicuna"
                model_size="7B"
                model_desc="wytrenowany na konwersacjach, dobry do dialogów"
                ;;
            10)
                model_name="falcon"
                model_size="7B"
                model_desc="szybki i efektywny, dobry stosunek wydajności do rozmiaru"
                ;;
            11)
                model_name="orca-mini"
                model_size="3B"
                model_desc="dobry do podstawowych zadań NLP"
                ;;
            12)
                model_name="wizardcoder"
                model_size="13B"
                model_desc="stworzony do zadań związanych z kodem"
                ;;
            13)
                model_name="llama2"
                model_size="7B"
                model_desc="sprawdzony w różnych zastosowaniach"
                ;;
            14)
                model_name="stablelm"
                model_size="3B"
                model_desc="dobry do generowania tekstu i dialogów"
                ;;
            15)
                model_name="dolphin"
                model_size="7B"
                model_desc="koncentruje się na naturalności dialogów"
                ;;
            16)
                model_name="neural-chat"
                model_size="7B"
                model_desc="zoptymalizowany pod kątem urządzeń Intel"
                ;;
            17)
                model_name="starling"
                model_size="7B"
                model_desc="mniejszy ale skuteczny"
                ;;
            18)
                model_name="openhermes"
                model_size="7B"
                model_desc="dobra dokładność, postępowanie zgodnie z instrukcjami"
                ;;
            19)
                model_name="yi"
                model_size="6B"
                model_desc="zaawansowany model wielojęzyczny"
                ;;
            20)
                # Pytanie o rozmiar
                echo -e "${BLUE}Popularne rozmiary modeli:${NC}"
                echo "1) mini - Bardzo małe modele (~1-3B parametrów) - szybkie, ale ograniczone możliwości"
                echo "2) small - Małe modele (~3-7B parametrów) - dobry kompromis szybkość/jakość"
                echo "3) medium - Średnie modele (~8-13B parametrów) - lepsze odpowiedzi, wymaga więcej RAM"
                echo "4) large - Duże modele (~30-70B parametrów) - najlepsza jakość, wysokie wymagania sprzętowe"
                read -p "Wybierz preferowany rozmiar modelu (1-4, Enter dla dowolnego): " size_choice

                # Pytanie o specjalizację
                echo -e "${BLUE}Zastosowanie modelu:${NC}"
                echo "1) Ogólnego przeznaczenia - do większości zadań"
                echo "2) Kod - wyspecjalizowany w programowaniu"
                echo "3) Matematyka/Nauka - lepszy w zadaniach naukowych"
                echo "4) Wielojęzyczny - dobry w wielu językach"
                echo "5) Konwersacyjny - zoptymalizowany pod kątem dialogów"
                read -p "Wybierz zastosowanie (1-5, Enter dla dowolnego): " purpose_choice

                read -p "Podaj nazwę modelu do pobrania: " model_name

                # Ustaw domyślne wartości
                model_size="?"
                model_desc="własny wybór"
                ;;
            *)
                log "error" "Nieprawidłowy wybór"
                return 1
                ;;
        esac

        log "info" "Pobieranie modelu $model_name (${model_size}, ${model_desc})..."
        ollama pull $model_name

        if [ $? -ne 0 ]; then
            log "error" "Nie udało się pobrać modelu $model_name"
            return 1
        else
            log "success" "Model $model_name został pobrany pomyślnie"
            MODELS_LOADED=true
        fi

        # Aktualizacja domyślnego modelu w pliku .env
        if [ -f ".env" ]; then
            # Sprawdzenie czy MODEL_NAME już istnieje w pliku
            if grep -q "^MODEL_NAME=" .env; then
                # Aktualizacja istniejącego wpisu
                sed -i.bak "s/^MODEL_NAME=.*/MODEL_NAME=\"$model_name:latest\"/" .env && rm -f .env.bak
            else
                # Dodanie nowego wpisu
                echo "MODEL_NAME=\"$model_name:latest\"" >> .env
            fi
            log "success" "Zaktualizowano domyślny model w pliku .env na $model_name:latest"
        fi
    fi

    return 0
}

# Funkcja do utworzenia lub aktualizacji pliku .env
update_env_file() {
    log "info" "Aktualizacja pliku konfiguracyjnego .env..."

    # Sprawdzenie czy plik .env już istnieje
    if [ -f ".env" ]; then
        # Aktualizacja portu jeśli podano inny
        if [ "$SERVER_PORT" != "5001" ]; then
            # Sprawdzenie czy SERVER_PORT już istnieje w pliku
            if grep -q "^SERVER_PORT=" .env; then
                # Aktualizacja istniejącego wpisu
                sed -i.bak "s/^SERVER_PORT=.*/SERVER_PORT=$SERVER_PORT/" .env && rm -f .env.bak
            else
                # Dodanie nowego wpisu
                echo "SERVER_PORT=$SERVER_PORT" >> .env
            fi
        fi
    else
        # Utworzenie nowego pliku .env
        echo "SERVER_PORT=$SERVER_PORT" > .env
        echo "OLLAMA_HOST=http://localhost:11434" >> .env

        # Jeśli pobraliśmy model, dodajmy go jako domyślny
        if [ "$MODELS_LOADED" = true ]; then
            echo "DEFAULT_MODEL=$model_name" >> .env
        fi
    fi

    log "success" "Plik .env został zaktualizowany"
    return 0
}

# Funkcja do uruchomienia serwera API
start_server() {
    log "info" "Uruchamianie serwera API (server.py)..."

    # Sprawdzenie czy server.py istnieje
    if [ ! -f "server.py" ]; then
        log "error" "Plik server.py nie istnieje"
        return 1
    fi

    # Pobranie portu z pliku .env jeśli istnieje
    if [ -f ".env" ]; then
        PORT_FROM_ENV=$(grep "^SERVER_PORT=" .env | cut -d'=' -f2)
        if [ ! -z "$PORT_FROM_ENV" ]; then
            SERVER_PORT=$PORT_FROM_ENV
        fi
    fi

    log "success" "Serwer będzie dostępny pod adresem: http://localhost:${SERVER_PORT}"
    log "warning" "Naciśnij Ctrl+C aby zatrzymać serwer"

    # Uruchomienie serwera
    $PYTHON server.py

    return $?
}

# Funkcja do zatrzymania Ollama
cleanup() {
    echo ""
    log "info" "Zatrzymywanie procesów..."

    # Zatrzymanie Ollama jeśli był uruchomiony przez ten skrypt
    if [ -f ".ollama.pid" ]; then
        OLLAMA_PID=$(cat .ollama.pid)
        if is_process_running $OLLAMA_PID; then
            log "info" "Zatrzymywanie serwera Ollama (PID: $OLLAMA_PID)..."
            kill $OLLAMA_PID
            rm .ollama.pid
        fi
    fi

    log "success" "Zakończono działanie skryptu"
    exit 0
}

# Funkcja do sprawdzenia wymagań systemowych
check_requirements() {
    log "info" "Sprawdzanie wymagań systemowych..."

    # Sprawdzenie Pythona
    check_python
    if [ $? -ne 0 ]; then
        log "error" "Sprawdzanie wymagań nie powiodło się: Brak Pythona 3"
        return 1
    fi

    # Sprawdzenie pip
    check_pip
    if [ $? -ne 0 ]; then
        log "error" "Sprawdzanie wymagań nie powiodło się: Brak pip"
        return 1
    fi

    # Sprawdzenie Ollama
    check_ollama
    if [ $? -ne 0 ]; then
        log "error" "Sprawdzanie wymagań nie powiodło się: Brak Ollama"
        return 1
    fi

    # Sprawdzenie pliku server.py
    check_server_file
    if [ $? -ne 0 ]; then
        log "error" "Sprawdzanie wymagań nie powiodło się: Brak pliku server.py"
        return 1
    fi

    log "success" "Wszystkie wymagania systemowe są spełnione"
    return 0
}

# Funkcja do konfiguracji środowiska
setup_environment() {
    log "info" "Konfiguracja środowiska..."

    # Sprawdzenie wymagań
    check_requirements
    if [ $? -ne 0 ]; then
        log "error" "Konfiguracja środowiska nie powiodła się"
        return 1
    fi

    # Instalacja pakietów
    install_packages
    if [ $? -ne 0 ]; then
        log "error" "Konfiguracja środowiska nie powiodła się: Błąd instalacji pakietów"
        return 1
    fi

    # Aktualizacja pliku .env
    update_env_file

    log "success" "Środowisko zostało pomyślnie skonfigurowane"
    return 0
}

# Główna funkcja
main() {
    # Analiza parametrów
    SETUP_ONLY=false
    RUN_ONLY=false
    MODELS_ONLY=false
    CHECK_ONLY=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--setup)
                SETUP_ONLY=true
                ;;
            -r|--run)
                RUN_ONLY=true
                ;;
            -p|--port)
                SERVER_PORT="$2"
                shift
                ;;
            -m|--models)
                MODELS_ONLY=true
                ;;
            -c|--check)
                CHECK_ONLY=true
                ;;
            *)
                log "error" "Nieznana opcja: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    # Ustaw trap dla Ctrl+C
    trap cleanup SIGINT SIGTERM

    echo -e "${BOLD}${BLUE}========================================================${NC}"
    echo -e "${BOLD}${BLUE}   Uniwersalne środowisko dla Ollama API   ${NC}"
    echo -e "${BOLD}${BLUE}========================================================${NC}"

    # Wykonaj akcje w zależności od parametrów
    if [ "$CHECK_ONLY" = true ]; then
        check_requirements
        exit $?
    fi

    if [ "$MODELS_ONLY" = true ]; then
        # Uruchomienie Ollama jeśli nie działa
        if ! curl -s --head --connect-timeout 2 http://localhost:11434 &> /dev/null; then
            start_ollama
        fi

        configure_models
        exit $?
    fi

    if [ "$SETUP_ONLY" = true ]; then
        setup_environment
        exit $?
    fi

    if [ "$RUN_ONLY" = true ]; then
        # Uruchomienie Ollama jeśli nie działa
        if ! curl -s --head --connect-timeout 2 http://localhost:11434 &> /dev/null; then
            log "info" "Serwer Ollama nie jest uruchomiony, próba uruchomienia..."
            start_ollama
            if [ $? -ne 0 ]; then
                log "error" "Nie udało się uruchomić serwera Ollama"
                log "warning" "Spróbuj uruchomić Ollama ręcznie: ollama serve"
                exit 1
            fi
        else
            log "success" "Serwer Ollama już działa"
        fi

        # Aktualizacja pliku .env jeśli podano port
        if [ "$SERVER_PORT" != "5001" ]; then
            update_env_file
        fi

        # Sprawdź czy server.py istnieje
        if [ ! -f "server.py" ]; then
            log "error" "Plik server.py nie istnieje w bieżącym katalogu"
            exit 1
        fi

        # Uruchom serwer
        start_server
        exit $?
    fi

    # Domyślna ścieżka - pełna konfiguracja i uruchomienie
    setup_environment
    if [ $? -ne 0 ]; then
        log "error" "Konfiguracja środowiska nie powiodła się"

        # Daj użytkownikowi wybór czy kontynuować mimo problemów
        read -p "Czy chcesz kontynuować mimo problemów z konfiguracją? (t/n): " continue_choice
        if [[ "$continue_choice" != "t" && "$continue_choice" != "T" ]]; then
            exit 1
        fi
        log "warning" "Kontynuowanie pomimo problemów z konfiguracją..."
    fi

    # Uruchomienie Ollama
    if ! curl -s --head --connect-timeout 2 http://localhost:11434 &> /dev/null; then
        log "info" "Uruchamianie serwera Ollama..."
        start_ollama
        if [ $? -ne 0 ]; then
            log "error" "Nie udało się uruchomić serwera Ollama"

            # Daj użytkownikowi wybór czy kontynuować bez Ollama
            read -p "Czy chcesz kontynuować bez działającego serwera Ollama? (t/n): " continue_choice
            if [[ "$continue_choice" != "t" && "$continue_choice" != "T" ]]; then
                exit 1
            fi
            log "warning" "Kontynuowanie bez działającego serwera Ollama..."
        fi
    else
        log "success" "Serwer Ollama już działa"
    fi

    # Pytanie o konfigurację modeli
    read -p "Czy chcesz skonfigurować modele Ollama? (t/n): " config_models
    if [[ "$config_models" == "t" || "$config_models" == "T" ]]; then
        configure_models
    fi

    # Uruchomienie serwera
    start_server

    # Czyszczenie po zakończeniu
    cleanup
}

# Uruchomienie głównej funkcji
main "$@"