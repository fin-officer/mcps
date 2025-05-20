# Konfiguracja serwera SMTP
SMTP_CONFIG = {
    "host": "smtp.example.com",  # Zmień na swój serwer SMTP
    "port": 587,
    "username": "user@example.com",  # Zmień na swój login
    "password": "password",  # Zmień na swoje hasło
    "use_tls": True
}

# Konfiguracja domyślnych ustawień email
DEFAULT_EMAIL = {
    "from_addr": "user@example.com",  # Zmień na swój adres email
    "reply_to": "user@example.com"  # Zmień na swój adres email
}
