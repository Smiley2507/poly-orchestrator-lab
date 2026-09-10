"""Thin Redis helper used for caching product data.

Cache failures are never fatal: if Redis is unreachable the API still
serves data straight from PostgreSQL.
"""
import json
import logging
from typing import Any, Optional

import redis

from .config import CACHE_TTL_SECONDS, REDIS_DB, REDIS_HOST, REDIS_PORT

logger = logging.getLogger("shopnow.cache")

client = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    db=REDIS_DB,
    decode_responses=True,
    socket_connect_timeout=2,
    socket_timeout=2,
)

PRODUCTS_KEY = "shopnow:products:all"


def product_key(product_id: int) -> str:
    return f"shopnow:products:{product_id}"


def cache_get(key: str) -> Optional[Any]:
    try:
        raw = client.get(key)
    except redis.RedisError as exc:
        logger.warning("Redis unavailable on GET %s (%s) - falling back to DB", key, exc)
        return None
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def cache_set(key: str, value: Any, ttl: int = CACHE_TTL_SECONDS) -> None:
    try:
        client.setex(key, ttl, json.dumps(value))
        logger.info("Cached %s for %ss", key, ttl)
    except redis.RedisError as exc:
        logger.warning("Redis unavailable on SET %s (%s) - continuing", key, exc)


def ping() -> bool:
    try:
        return bool(client.ping())
    except redis.RedisError:
        return False
