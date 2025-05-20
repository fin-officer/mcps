# Konfiguracja Ollama

OLLAMA_CONFIG = {
    "base_url": "http://localhost:11434",
    "model": "tinyllama",  # Można zmienić na inny model
    "timeout": 30
}

# Parametry generacji
GENERATION_PARAMS = {
    "temperature": 0.7,
    "top_p": 0.9,
    "max_tokens": 1000
}
