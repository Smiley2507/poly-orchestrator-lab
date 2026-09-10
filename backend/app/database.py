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
    # name, description, price, image_url, in_stock
    ("Aurora 14 Laptop", "14-inch ultrabook with 16GB RAM, 512GB SSD and all-day battery life.", 1299.00, "/products/laptop.svg", True),
    ("Wireless Mouse", "Ergonomic 2.4GHz wireless mouse with silent clicks and a 12-month battery life.", 24.99, "/products/mouse.svg", True),
    ("Mechanical Keyboard", "Compact keyboard with tactile brown switches and per-key backlighting.", 89.50, "/products/keyboard.svg", True),
    ("27\" QHD Monitor", "27-inch QHD IPS display with a 75Hz refresh rate, ideal for work and everyday browsing.", 249.00, "/products/monitor.svg", True),
    ("USB-C Hub", "7-in-1 hub with HDMI, Ethernet, an SD card reader and 100W pass-through charging.", 39.95, "/products/hub.svg", True),
    ("Wireless Headphones", "Over-ear headphones with active noise cancelling and a 30-hour battery life.", 129.00, "/products/headphones.svg", True),
    ("HD Webcam", "1080p webcam with autofocus and a built-in privacy shutter.", 54.99, "/products/webcam.svg", True),
    ("Portable SSD 1TB", "1TB portable SSD with USB-C connectivity and read speeds up to 1050MB/s.", 109.00, "/products/ssd.svg", False),
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
            Product(name=n, description=d, price=p, image_url=img, in_stock=stock)
            for n, d, p, img, stock in SAMPLE_PRODUCTS
        )
        db.commit()
        logger.info("Seeded %d sample products", len(SAMPLE_PRODUCTS))
