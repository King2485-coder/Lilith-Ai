from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    app_env: str
    database_url: str
    redis_url: str
    jwt_secret: str
    jwt_algorithm: str
    token_expire_minutes: int
    jwt_issuer: str
    jwt_audience: str
    jwt_leeway_seconds: int
    data_encryption_key: str
    cors_origins: str
    global_rate_limit_per_minute: int
    auth_rate_limit_per_minute: int
    message_rate_limit_per_minute: int
    payment_rate_limit_per_minute: int
    tool_rate_limit_per_minute: int


def load_settings() -> Settings:
    return Settings(
        app_env=os.getenv("APP_ENV", "development"),
        database_url=os.getenv("DATABASE_URL", "sqlite:///./lilith.db"),
        redis_url=os.getenv("REDIS_URL", "redis://localhost:6379/0"),
        jwt_secret=os.getenv("JWT_SECRET", "change-me-in-production"),
        jwt_algorithm=os.getenv("JWT_ALGORITHM", "HS256"),
        token_expire_minutes=int(os.getenv("TOKEN_EXPIRE_MINUTES", "60")),
        jwt_issuer=os.getenv("JWT_ISSUER", "lilith-api"),
        jwt_audience=os.getenv("JWT_AUDIENCE", "lilith-clients"),
        jwt_leeway_seconds=int(os.getenv("JWT_LEEWAY_SECONDS", "10")),
        data_encryption_key=os.getenv("DATA_ENCRYPTION_KEY", ""),
        cors_origins=os.getenv("CORS_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000"),
        global_rate_limit_per_minute=int(os.getenv("GLOBAL_RATE_LIMIT_PER_MINUTE", "300")),
        auth_rate_limit_per_minute=int(os.getenv("AUTH_RATE_LIMIT_PER_MINUTE", "40")),
        message_rate_limit_per_minute=int(os.getenv("MESSAGE_RATE_LIMIT_PER_MINUTE", "90")),
        payment_rate_limit_per_minute=int(os.getenv("PAYMENT_RATE_LIMIT_PER_MINUTE", "50")),
        tool_rate_limit_per_minute=int(os.getenv("TOOL_RATE_LIMIT_PER_MINUTE", "80")),
    )


settings = load_settings()
