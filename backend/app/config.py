"""Configuration loaded entirely from environment variables.

No infrastructure hostname is hard-coded, so the same image runs against
Docker Compose services locally and against RDS / ElastiCache later.
"""
import os


def _env(name: str, default: str) -> str:
    return os.getenv(name, default)


# --- PostgreSQL ---
DATABASE_HOST = _env("DATABASE_HOST", "postgres")
DATABASE_PORT = _env("DATABASE_PORT", "5432")
DATABASE_NAME = _env("DATABASE_NAME", "shopnow")
DATABASE_USER = _env("DATABASE_USER", "shopnow")
DATABASE_PASSWORD = _env("DATABASE_PASSWORD", "shopnow_local_dev")

DATABASE_URL = (
    f"postgresql+psycopg://{DATABASE_USER}:{DATABASE_PASSWORD}"
    f"@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_NAME}"
)

# --- Redis ---
REDIS_HOST = _env("REDIS_HOST", "redis")
REDIS_PORT = int(_env("REDIS_PORT", "6379"))
REDIS_DB = int(_env("REDIS_DB", "0"))
CACHE_TTL_SECONDS = int(_env("CACHE_TTL_SECONDS", "60"))

# --- App ---
CORS_ORIGINS = [o.strip() for o in _env("CORS_ORIGINS", "*").split(",") if o.strip()]
