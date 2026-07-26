import json
from typing import Any, Dict, List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "CineTrack API"
    ENVIRONMENT: str = "local"
    
    # Database connection URL
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/cinetrack"
    
    # CORS Origins allowed to make requests to this FastAPI backend
    CORS_ORIGINS: List[str] = [
        "http://localhost:8000",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost"
    ]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Any) -> List[str]:
        if isinstance(v, str):
            v_stripped = v.strip()
            if not v_stripped:
                return []
            if v_stripped.startswith("[") and v_stripped.endswith("]"):
                try:
                    return json.loads(v_stripped)
                except json.JSONDecodeError:
                    pass
            return [i.strip() for i in v_stripped.split(",") if i.strip()]
        elif isinstance(v, list):
            return [str(item) for item in v]
        raise ValueError(f"Invalid format for CORS_ORIGINS: {v}")

    # Security settings
    SECRET_KEY: str = "default_secret_key_change_me_in_production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 11520  # 8 days

    # Configuration for Settings model behavior
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )

settings = Settings()
