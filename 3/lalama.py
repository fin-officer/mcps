#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import time
import subprocess
import sys
import re
from typing import List, Dict, Any, Tuple, Optional


# Funkcja do instalacji podstawowych zależności
def ensure_basic_dependencies():
    """Sprawdza i instaluje podstawowe zależności potrzebne do działania skryptu."""
    basic_dependencies = ['setuptools', 'requests']

    for dep in basic_dependencies:
        try:
            # Próba importu, aby sprawdzić czy jest zainstalowany
            __import__(dep)
        except ImportError:
            print(f"Instalowanie podstawowej zależności: {dep}...")
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", dep])
                print(f"Zainstalowano {dep}")
            except subprocess.CalledProcessError:
                print(f"Nie udało się zainstalować {dep}. Przerwanie.")
                sys.exit(1)


# Instalacja podstawowych zależności przed importowaniem pozostałych modułów
ensure_basic_dependencies()

# Teraz importujemy pozostałe moduły
import requests
import importlib
import pkg_resources  # Z setuptools


class OllamaRunner:
    """Klasa do uruchamiania Ollama i wykonywania wygenerowanego kodu."""

    def __init__(self, ollama_path: str = "ollama", model: str = "llama3"):
        self.ollama_path = ollama_path
        self.model = model
        self.ollama_process = None
        self.api_url = "http://localhost:11434/api/generate"

    def start_ollama(self) -> None:
        """Uruchom serwer Ollama jeśli nie jest już uruchomiony."""
        try:
            # Sprawdź czy Ollama już działa
            response = requests.get("http://localhost:11434/api/tags")
            print("Ollama już działa")
        except requests.exceptions.ConnectionError:
            print("Uruchamianie serwera Ollama...")
            # Uruchom Ollama w tle
            self.ollama_process = subprocess.Popen(
                [self.ollama_path, "serve"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            # Poczekaj na uruchomienie serwera
            time.sleep(5)
            print("Serwer Ollama uruchomiony")

    def stop_ollama(self) -> None:
        """Zatrzymaj serwer Ollama jeśli został uruchomiony przez ten skrypt."""
        if self.ollama_process:
            print("Zatrzymywanie serwera Ollama...")
            self.ollama_process.terminate()
            self.ollama_process.wait()
            print("Serwer Ollama zatrzymany")

    def query_ollama(self, prompt: str) -> str:
        """Wyślij zapytanie do API Ollama i zwróć odpowiedź."""
        print(f"Wysyłanie zapytania do modelu {self.model}...")

        data = {
            "model": self.model,
            "prompt": prompt,
            "stream": False
        }

        response = requests.post(self.api_url, json=data)
        response_json = response.json()

        return response_json.get("response", "")

    def extract_python_code(self, text: str) -> str:
        """Wyodrębnij kod Python z odpowiedzi."""
        pattern = r"```python\s*(.*?)\s*```"
        match = re.search(pattern, text, re.DOTALL)
        if match:
            return match.group(1)
        return ""

    def save_code_to_file(self, code: str, filename: str = "generated_script.py") -> str:
        """Zapisz wygenerowany kod do pliku i zwróć ścieżkę do pliku."""
        with open(filename, "w", encoding="utf-8") as f:
            f.write(code)
        return os.path.abspath(filename)


class DependencyManager:
    """Klasa do zarządzania zależnościami projektu."""

    @staticmethod
    def extract_imports(code: str) -> List[str]:
        """Wyodrębnij importowane moduły z kodu."""
        # Regex do znalezienia importowanych modułów
        import_patterns = [
            r"import\s+([a-zA-Z0-9_]+)",  # import numpy
            r"from\s+([a-zA-Z0-9_]+)\s+import",  # from numpy import array
            r"import\s+([a-zA-Z0-9_]+)\s+as",  # import numpy as np
        ]

        modules = []
        for pattern in import_patterns:
            matches = re.finditer(pattern, code)
            for match in matches:
                module_name = match.group(1)
                # Pobierz tylko główny moduł (np. dla 'selenium.webdriver' weź tylko 'selenium')
                base_module = module_name.split('.')[0]
                if base_module not in modules:
                    modules.append(base_module)

        return modules

    @staticmethod
    def get_installed_packages() -> Dict[str, str]:
        """Pobierz listę zainstalowanych pakietów."""
        return {pkg.key: pkg.version for pkg in pkg_resources.working_set}

    @staticmethod
    def check_dependencies(modules: List[str]) -> Tuple[List[str], List[str]]:
        """Sprawdź, które zależności są już zainstalowane, a których brakuje."""
        installed_packages = DependencyManager.get_installed_packages()

        installed = []
        missing = []

        for module in modules:
            try:
                importlib.import_module(module)
                installed.append(module)
            except ImportError:
                # Sprawdź, czy nazwa modułu różni się od nazwy pakietu
                package_mapping = {
                    'PIL': 'pillow',
                    'cv2': 'opencv-python',
                    'sklearn': 'scikit-learn',
                    'bs4': 'beautifulsoup4',
                }

                package_name = package_mapping.get(module, module)
                if package_name.lower() in installed_packages:
                    installed.append(module)
                else:
                    missing.append(package_name)

        return installed, missing

    @staticmethod
    def install_dependencies(packages: List[str]) -> bool:
        """Zainstaluj brakujące zależności."""
        if not packages:
            return True

        print(f"Instalowanie zależności: {', '.join(packages)}...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install"] + packages)
            print("Zależności zainstalowane pomyślnie")
            return True
        except subprocess.CalledProcessError:
            print("Wystąpił błąd podczas instalacji zależności")
            return False


def main():
    """Główna funkcja programu."""
    try:
        # Sprawdź, czy Ollama jest zainstalowana
        try:
            subprocess.run([os.environ.get("OLLAMA_PATH", "ollama"), "--version"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        except FileNotFoundError:
            print("Ollama nie jest zainstalowana lub nie jest dostępna w ścieżce systemowej.")
            print("Proszę zainstalować Ollama: https://ollama.ai/download")
            return

        # Utwórz instancje klas
        ollama = OllamaRunner()
        dependency_manager = DependencyManager()

        # Uruchom Ollama
        ollama.start_ollama()

        # Zapytanie takie samo jak w przykładzie
        prompt = "create the sentence as python code: Create screenshot on browser"

        # Wyślij zapytanie do Ollama
        response = ollama.query_ollama(prompt)

        # Wyodrębnij kod Python z odpowiedzi
        code = ollama.extract_python_code(response)

        if not code:
            print("Nie udało się wyodrębnić kodu Python z odpowiedzi.")
            return

        # Zapisz kod do pliku
        code_file = ollama.save_code_to_file(code)
        print(f"Kod zapisany do pliku: {code_file}")

        # Znajdź i zainstaluj zależności
        modules = dependency_manager.extract_imports(code)
        installed, missing = dependency_manager.check_dependencies(modules)

        print(f"Znalezione moduły: {', '.join(modules)}")
        print(f"Zainstalowane moduły: {', '.join(installed)}")

        if missing:
            print(f"Brakujące zależności: {', '.join(missing)}")
            if not dependency_manager.install_dependencies(missing):
                print("Przerwano wykonywanie skryptu z powodu błędu instalacji zależności.")
                return
        else:
            print("Wszystkie zależności są już zainstalowane")

        # Wykonaj wygenerowany kod
        print("\nUruchamianie wygenerowanego kodu...")
        subprocess.run([sys.executable, code_file])

    except Exception as e:
        print(f"Wystąpił błąd: {e}")
        import traceback
        traceback.print_exc()

    finally:
        # Zatrzymaj Ollama jeśli została uruchomiona przez ten skrypt
        if 'ollama' in locals():
            ollama.stop_ollama()


if __name__ == "__main__":
    # Sprawdź czy skrypt jest uruchomiony bezpośrednio (nie zaimportowany)
    # Najpierw zainstaluj podstawowe zależności
    ensure_basic_dependencies()
    main()