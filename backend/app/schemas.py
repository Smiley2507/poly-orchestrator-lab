"""Pydantic response schemas."""
from pydantic import BaseModel, ConfigDict


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    price: float
    image_url: str
    in_stock: bool


class HealthOut(BaseModel):
    status: str
