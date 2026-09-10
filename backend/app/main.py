"""ShopNow backend API.

Flow for GET /api/products:
    Redis  -> hit  -> return cached payload
           -> miss -> PostgreSQL -> store in Redis -> return
"""
import logging
import time

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import redis_client
from .config import CORS_ORIGINS
from .database import get_db, init_db
from .models import Product
from .schemas import HealthOut, ProductOut

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("shopnow.api")

app = FastAPI(title="ShopNow API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    """Wait briefly for PostgreSQL, then create tables and seed sample rows."""
    last_error = None
    for attempt in range(1, 31):
        try:
            init_db()
            logger.info("Database ready")
            break
        except Exception as exc:  # noqa: BLE001 - startup retry loop
            last_error = exc
            logger.warning("Database not ready (attempt %d/30): %s", attempt, exc)
            time.sleep(2)
    else:
        raise RuntimeError(f"Could not initialize database: {last_error}")


@app.get("/health", response_model=HealthOut)
def health() -> HealthOut:
    """Liveness endpoint - kept trivially simple for ECS/ALB health checks."""
    return HealthOut(status="healthy")


@app.get("/api/products", response_model=list[ProductOut])
def list_products(db: Session = Depends(get_db)) -> list[dict]:
    cached = redis_client.cache_get(redis_client.PRODUCTS_KEY)
    if cached is not None:
        logger.info("CACHE HIT  -> Redis (%s)", redis_client.PRODUCTS_KEY)
        return cached

    logger.info("CACHE MISS -> PostgreSQL (%s)", redis_client.PRODUCTS_KEY)
    rows = db.scalars(select(Product).order_by(Product.id)).all()
    payload = [ProductOut.model_validate(r).model_dump() for r in rows]
    redis_client.cache_set(redis_client.PRODUCTS_KEY, payload)
    return payload


@app.get("/api/products/{product_id}", response_model=ProductOut)
def get_product(product_id: int, db: Session = Depends(get_db)) -> dict:
    key = redis_client.product_key(product_id)
    cached = redis_client.cache_get(key)
    if cached is not None:
        logger.info("CACHE HIT  -> Redis (%s)", key)
        return cached

    logger.info("CACHE MISS -> PostgreSQL (%s)", key)
    row = db.get(Product, product_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Product not found")
    payload = ProductOut.model_validate(row).model_dump()
    redis_client.cache_set(key, payload)
    return payload
