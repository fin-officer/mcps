# Konfiguracja modelu Ollama

# Podstawowa konfiguracja
OLLAMA_CONFIG = {
    "base_url": "http://localhost:11434",  # Domyślny port Ollama
    "model": "tinyllama:latest",           # Model Tiny LLama (można zmienić na dowolny dostępny model)
    "timeout": 60,                         # Timeout w sekundach
}

# Parametry generacji
GENERATION_PARAMS = {
    "temperature": 0.7,
    "top_p": 0.9,
    "top_k": 40,
    "max_tokens": 2048,
    "presence_penalty": 1.0,
    "frequency_penalty": 1.0,
}
