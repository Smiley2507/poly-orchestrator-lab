"""SQLAlchemy engine/session setup and simple startup initialization."""
import logging

from sqlalchemy import create_engine, select
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import DATABASE_URL

logger = logging.getLogger("shopnow.database")

engine = create_engine(DATABASE_URL, pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    """FastAPI dependency yielding a session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


SAMPLE_PRODUCTS = [
    ("Laptop", "14-inch ultrabook with 16GB RAM and 512GB SSD", 1299.00),
    ("Wireless Mouse", "Ergonomic 2.4GHz wireless mouse", 24.99),
    ("Mechanical Keyboard", "Compact keyboard with tactile brown switches", 89.50),
    ("Monitor", "27-inch QHD IPS display, 75Hz", 249.00),
    ("USB-C Hub", "7-in-1 hub with HDMI, Ethernet and card reader", 39.95),
]


def init_db() -> None:
    """Create tables and seed sample products if the table is empty."""
    from .models import Product  # imported here so Base has the mapping

    Base.metadata.create_all(bind=engine)

    with SessionLocal() as db:
        existing = db.scalar(select(Product).limit(1))
        if existing is not None:
            logger.info("Products table already populated - skipping seed")
            return
        db.add_all(
            Product(name=n, description=d, price=p) for n, d, p in SAMPLE_PRODUCTS
        )
        db.commit()
        logger.info("Seeded %d sample products", len(SAMPLE_PRODUCTS))
