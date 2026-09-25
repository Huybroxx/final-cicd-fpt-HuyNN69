from datetime import datetime, timezone
from typing import Optional
from pydantic import BaseModel, Field


class ItemBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=100, description="Title of the item")
    description: Optional[str] = Field(None, max_length=500, description="Detailed description")
    price: float = Field(..., gt=0, description="Price in USD")
    is_active: bool = Field(default=True, description="Status of the item")


class ItemCreate(ItemBase):
    pass


class ItemUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    price: Optional[float] = Field(None, gt=0)
    is_active: Optional[bool] = None


class ItemResponse(ItemBase):
    id: int
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Config:
        from_attributes = True


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str
    environment: str
    color: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
