@echo off
:: Skrypt instalacyjny do przygotowania środowiska dla server.py (wersja Windows)
:: Działa bez tworzenia dodatkowych plików

echo ========================================================
echo    Przygotowanie srodowiska dla Ollama API (server.py)
echo ========================================================

:: Sprawdzanie Pythona
echo Sprawdzanie instalacji Pythona...
where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Python nie jest zainstalowany lub nie jest dostepny w PATH
    echo Prosze zainstalowac Python 3 ze strony: https://www.python.org/downloads/
    echo i upewnic sie, ze opcja "Add Python to PATH" jest zaznaczona
    pause
    exit /b 1
)

:: Sprawdzenie wersji Pythona
python --version | find "Python 3" >nul
if %ERRORLEVEL% NEQ 0 (
    echo Wymagana jest wersja Python 3.x
    pause
    exit /b 1
)

:: Sprawdzanie pip
echo Sprawdzanie instalacji pip...
python -m pip --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Pip nie jest zainstalowany
    echo Instalowanie pip...
    curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py
    del get-pip.py
    
    python -m pip --version >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo Nie udalo sie zainstalowac pip
        echo Prosze zainstalowac pip recznie: https://pip.pypa.io/en/stable/installation/
        pause
        exit /b 1
    )
)

:: Sprawdzanie Ollama
echo Sprawdzanie instalacji Ollama...
where ollama >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo UWAGA: Ollama nie jest zainstalowana lub nie jest dostepna w PATH
    echo Ollama jest wymagana do dzialania serwera
    echo Pobierz Ollama ze strony: https://ollama.com/download
    echo i zainstaluj zgodnie z instrukcjami dla Windows
    
    set /p continue_choice="Czy chcesz kontynuowac instalacje mimo braku Ollama? (t/n): "
    if /i not "%continue_choice%"=="t" (
        pause
        exit /b 1
    )
)

:: Instalacja wymaganych pakietów Python
echo Instalacja wymaganych pakietow Python...
python -m pip install flask requests python-dotenv

:: Sprawdzenie instalacji pakietów
set missing=0
python -c "import flask" >nul 2>&1 || set /a missing+=1
python -c "import requests" >nul 2>&1 || set /a missing+=1
python -c "import dotenv" >nul 2>&1 || set /a missing+=1

if %missing% GTR 0 (
    echo Nie udalo sie zainstalowac wszystkich wymaganych pakietow
    echo Sprobuj zainstalowac je recznie: python -m pip install flask requests python-dotenv
    pause
    exit /b 1
)

:: Sprawdzenie czy server.py istnieje
if not exist server.py (
    echo UWAGA: Plik server.py nie zostal znaleziony w biezacym katalogu
    echo Upewnij sie, ze plik server.py znajduje sie w tym samym katalogu co skrypt setup_env.bat
)

:: Zakończenie
echo ========================================================
echo    Srodowisko zostalo pomyslnie przygotowane!
echo ========================================================
echo.
echo Aby uruchomic serwer:
echo python server.py
echo.
echo Serwer bedzie dostepny pod adresem:
echo http://localhost:5001
echo.
echo Jesli chcesz zmienic port, utworz plik .env z zawartoscia:
echo SERVER_PORT=8080
echo.

:: Pytanie czy uruchomić serwer od razu
set /p run_server="Czy chcesz uruchomic serwer teraz? (t/n): "
if /i "%run_server%"=="t" (
    echo Uruchamianie serwera...
    echo Nacisnij Ctrl+C aby zatrzymac serwer
    python server.py
) else (
    echo Mozesz uruchomic serwer pozniej komenda: python server.py
    pause
)