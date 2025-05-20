"""Configuration management for MCP servers."""
import os
from typing import Any, Dict, List, Optional, Union
from pydantic import BaseSettings, Field, validator, HttpUrl, PostgresDsn, validator
from functools import lru_cache
from dotenv import load_dotenv

# Load environment variables from .env file if it exists
load_dotenv()

class Settings(BaseSettings):
    # Application settings
    APP_NAME: str = "MCP_Server"
    APP_VERSION: str = "0.1.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    
    # Server settings
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 1
    RELOAD: bool = False
    
    # CORS settings
    CORS_ORIGINS: List[str] = ["*"]
    CORS_METHODS: List[str] = ["*"]
    CORS_HEADERS: List[str] = ["*"]
    
    # Authentication
    SECRET_KEY: str = "your-secret-key-here"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Database
    DATABASE_URL: str = "sqlite:///./mcp.db"
    DATABASE_ECHO: bool = False
    
    # Docker settings
    DOCKER_HOST: str = "unix:///var/run/docker.sock"
    DOCKER_PORT: int = 8001
    DOCKER_TLS_VERIFY: bool = False
    DOCKER_CERT_PATH: Optional[str] = None
    
    # Email settings
    EMAIL_PORT: int = 8002
    SMTP_SERVER: str = "smtp.example.com"
    SMTP_PORT: int = 587
    SMTP_USE_TLS: bool = True
    SMTP_USERNAME: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_FROM: str = "no-reply@example.com"
    SMTP_TIMEOUT: int = 10
    
    # Filesystem settings
    FILESYSTEM_PORT: int = 8003
    FILESYSTEM_BASE_PATH: str = "/data"
    FILESYSTEM_READ_ONLY: bool = False
    
    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FILE: str = "logs/mcp.log"
    LOG_MAX_SIZE: int = 10  # MB
    LOG_BACKUP_COUNT: int = 5
    LOG_FORMAT: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    
    # Rate limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_DEFAULT: str = "100/minute"
    RATE_LIMIT_STORAGE_URL: str = "memory://"
    
    # Monitoring
    PROMETHEUS_ENABLED: bool = True
    PROMETHEUS_PORT: int = 9090
    METRICS_ENABLED: bool = True
    
    # Security
    ALLOWED_HOSTS: List[str] = ["*"]
    TRUSTED_PROXIES: List[str] = ["127.0.0.1", "::1"]
    SECURE_PROXY_SSL_HEADER: bool = True
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True
    
    @validator("DATABASE_URL", pre=True)
    def assemble_db_connection(cls, v: Optional[str], values: Dict[str, Any]) -> Any:
        if isinstance(v, str):
            return v
        return "sqlite:///./mcp.db"
    
    @validator("CORS_ORIGINS", "CORS_METHODS", "CORS_HEADERS", "ALLOWED_HOSTS", "TRUSTED_PROXIES", pre=True)
    def assemble_list(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        return v

@lru_cache()
def get_settings() -> Settings:
    """Get settings with caching."""
    return Settings()

# Global settings object
settings = get_settings()

def get_database_url() -> str:
    """Get the database URL from settings."""
    return settings.DATABASE_URL

def get_logging_config() -> dict:
    """Get logging configuration."""
    return {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "standard": {
                "format": settings.LOG_FORMAT,
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
        },
        "handlers": {
            "console": {
                "level": settings.LOG_LEVEL,
                "class": "logging.StreamHandler",
                "formatter": "standard",
            },
            "file": {
                "level": settings.LOG_LEVEL,
                "class": "logging.handlers.RotatingFileHandler",
                "filename": settings.LOG_FILE,
                "maxBytes": settings.LOG_MAX_SIZE * 1024 * 1024,  # MB to bytes
                "backupCount": settings.LOG_BACKUP_COUNT,
                "formatter": "standard",
                "encoding": "utf8",
            },
        },
        "loggers": {
            "": {"handlers": ["console", "file"], "level": settings.LOG_LEVEL},
            "uvicorn": {"handlers": ["console", "file"], "level": settings.LOG_LEVEL},
            "uvicorn.error": {"level": settings.LOG_LEVEL},
            "fastapi": {"handlers": ["console", "file"], "level": settings.LOG_LEVEL},
        },
    }
