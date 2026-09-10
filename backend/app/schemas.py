"""Pydantic response schemas."""
from pydantic import BaseModel, ConfigDict


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    price: float


class HealthOut(BaseModel):
    status: str
