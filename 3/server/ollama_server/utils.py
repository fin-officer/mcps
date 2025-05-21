"""
Moduł zawierający funkcje pomocnicze dla Ollama Server.
"""

import os
import platform
import subprocess
import logging
from typing import Optional, Dict, Any, List, Tuple

# Konfiguracja logowania
logger = logging.getLogger("ollama_server.utils")


def check_ollama_installed() -> bool:
    """
    Sprawdza czy Ollama jest zainstalowana w systemie.

    Returns:
        bool: True jeśli Ollama jest zainstalowana, False w przeciwnym razie.
    """
    try:
        # Sprawdź czy komenda ollama jest dostępna
        subprocess.run(
            ["ollama", "--version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False
        )
        return True
    except FileNotFoundError:
        return False


def get_system_info() -> Dict[str, Any]:
    """
    Pobiera informacje o systemie.

    Returns:
        dict: Słownik z informacjami o systemie.
    """
    system_info = {
        "system": platform.system(),
        "release": platform.release(),
        "version": platform.version(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "python_version": platform.python_version(),
    }

    # Pobierz informacje o pamięci RAM
    try:
        import psutil
        memory = psutil.virtual_memory()
        system_info["memory_total"] = memory.total
        system_info["memory_available"] = memory.available
    except ImportError:
        system_info["memory_total"] = "Niedostępne (wymagany pakiet psutil)"
        system_info["memory_available"] = "Niedostępne (wymagany pakiet psutil)"

    return system_info


def suggest_model_by_system() -> str:
    """
    Sugeruje model Ollama na podstawie specyfikacji systemu.

    Returns:
        str: Nazwa sugerowanego modelu.
    """
    try:
        import psutil
        memory = psutil.virtual_memory()
        total_gb = memory.total / (1024 ** 3)  # Konwersja do GB

        if total_gb < 8:
            return "tinyllama:latest"  # Najmniejszy model
        elif total_gb < 16:
            return "phi3:latest"  # Mały model
        elif total_gb < 32:
            return "mistral:latest"  # Średni model
        else:
            return "llama3:latest"  # Standardowy model
    except ImportError:
        # Domyślny model w przypadku braku możliwości sprawdzenia RAM
        return "mistral:latest"


def format_bytes(size_bytes: int) -> str:
    """
    Formatuje rozmiar w bajtach do czytelnej postaci.

    Args:
        size_bytes: Rozmiar w bajtach.

    Returns:
        str: Sformatowany ciąg znaków z jednostką.
    """
    if size_bytes == 0:
        return "0 B"

    size_names = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    i = 0
    while size_bytes >= 1024 and i < len(size_names) - 1:
        size_bytes /= 1024
        i += 1

    return f"{size_bytes:.2f} {size_names[i]}"


def find_ollama_process() -> Optional[int]:
    """
    Znajduje PID procesu Ollama.

    Returns:
        Optional[int]: PID procesu lub None jeśli nie znaleziono.
    """
    try:
        import psutil
        for proc in psutil.process_iter(['pid', 'name']):
            if 'ollama' in proc.info['name'].lower():
                return proc.info['pid']
        return None
    except ImportError:
        logger.warning("Nie można znaleźć procesu Ollama: wymagany pakiet psutil")
        return None


def start_ollama_process() -> Tuple[bool, Optional[int]]:
    """
    Uruchamia proces Ollama w tle.

    Returns:
        Tuple[bool, Optional[int]]: (sukces, pid procesu lub None)
    """
    try:
        # Uruchom Ollama w tle
        if platform.system() == "Windows":
            process = subprocess.Popen(
                ["ollama", "serve"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP
            )
        else:
            process = subprocess.Popen(
                ["ollama", "serve"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True
            )

        # Daj czas na uruchomienie
        import time
        time.sleep(2)

        # Sprawdź czy proces działa
        if process.poll() is None:
            return True, process.pid
        else:
            return False, None
    except Exception as e:
        logger.error(f"Błąd podczas uruchamiania Ollama: {str(e)}")
        return False, None


def stop_ollama_process(pid: Optional[int] = None) -> bool:
    """
    Zatrzymuje proces Ollama.

    Args:
        pid: PID procesu do zatrzymania (jeśli None, szuka procesu)

    Returns:
        bool: True jeśli udało się zatrzymać proces, False w przeciwnym razie.
    """
    if pid is None:
        pid = find_ollama_process()

    if pid is None:
        # Proces już nie działa
        return True

    try:
        import psutil
        process = psutil.Process(pid)
        process.terminate()

        # Daj czas na zatrzymanie procesu
        import time
        for _ in range(5):  # Czekaj maksymalnie 5 sekund
            if not psutil.pid_exists(pid):
                return True
            time.sleep(1)

        # Jeśli proces nadal działa, zabij go
        if psutil.pid_exists(pid):
            process.kill()
            return True
    except ImportError:
        # Jeśli psutil nie jest dostępny, użyj platform-specyficznych komend
        if platform.system() == "Windows":
            subprocess.run(["taskkill", "/F", "/PID", str(pid)], check=False)
        else:
            subprocess.run(["kill", "-9", str(pid)], check=False)
        return True
    except Exception as e:
        logger.error(f"Błąd podczas zatrzymywania Ollama: {str(e)}")
        return False


def is_ollama_running() -> bool:
    """
    Sprawdza czy proces Ollama jest uruchomiony.

    Returns:
        bool: True jeśli Ollama jest uruchomiona, False w przeciwnym razie.
    """
    # Sprawdź czy proces istnieje
    pid = find_ollama_process()
    if pid is None:
        return False

    # Sprawdź czy API działa
    import requests
    try:
        response = requests.head("http://localhost:11434", timeout=1)
        return response.status_code == 200
    except requests.RequestException:
        return False


def check_port_availability(port: int) -> bool:
    """
    Sprawdza czy port jest dostępny.

    Args:
        port: Numer portu do sprawdzenia.

    Returns:
        bool: True jeśli port jest dostępny, False w przeciwnym razie.
    """
    import socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex(('127.0.0.1', port))
    sock.close()
    return result != 0  # Jeśli result != 0, port jest dostępny


def find_available_port(start_port: int = 5000, max_port: int = 6000) -> Optional[int]:
    """
    Znajduje dostępny port, zaczynając od start_port.

    Args:
        start_port: Początkowy port do sprawdzenia.
        max_port: Maksymalny port do sprawdzenia.

    Returns:
        Optional[int]: Dostępny port lub None jeśli nie znaleziono.
    """
    for port in range(start_port, max_port + 1):
        if check_port_availability(port):
            return port
    return None


if __name__ == "__main__":
    # Jeśli uruchomiony bezpośrednio, wyświetl informacje o systemie
    print("Informacje o systemie:")
    for key, value in get_system_info().items():
        print(f"  - {key}: {value}")

    print("\nSugerowany model Ollama:")
    print(f"  - {suggest_model_by_system()}")

    print("\nStatus Ollama:")
    if is_ollama_running():
        print("  - ✅ Ollama jest uruchomiona")
    else:
        print("  - ❌ Ollama nie jest uruchomiona")