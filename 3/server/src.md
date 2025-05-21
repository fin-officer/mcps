server/
│
├── ollama_server/               # Główny pakiet
│   ├── __init__.py              # Inicjalizacja pakietu
│   ├── api.py                   # API i endpointy Flask
│   ├── cli.py                   # Interfejs wiersza poleceń 
│   ├── config.py                # Konfiguracja i ładowanie ustawień
│   ├── models.py                # Operacje na modelach Ollama
│   ├── server.py                # Główny serwer Flask
│   ├── utils.py                 # Funkcje pomocnicze
│   └── web/                     # Pliki związane z interfejsem webowym
│       ├── __init__.py
│       ├── static/              # Statyczne pliki (CSS, JS)
│       │   ├── css/
│       │   │   └── style.css
│       │   └── js/
│       │       └── script.js
│       └── templates/           # Szablony HTML
│           ├── base.html
│           └── index.html
│
├── scripts/                     # Skrypty pomocnicze
│   ├── install.sh               # Uniwersalny skrypt instalacyjny
│   └── setup_models.sh          # Skrypt do konfiguracji modeli
│
├── tests/                       # Testy
│   ├── __init__.py
│   ├── test_api.py
│   ├── test_config.py
│   └── test_models.py
│
├── .env.example                 # Przykładowy plik .env
├── .gitignore                   # Pliki ignorowane przez Git
├── LICENSE                      # Licencja projektu
├── README.md                    # Dokumentacja projektu
└── pyproject.toml              # Konfiguracja Poetry
