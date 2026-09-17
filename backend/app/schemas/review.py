from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class ReviewCreate(BaseModel):
    movie_id: int
    # 👇 Increased max limit to 10.0 to match the frontend slider
    rating: float = Field(..., ge=1.0, le=10.0)
    comment: Optional[str] = None

class ReviewResponse(BaseModel):
    id: int
    user_id: int
    username: str
    movie_id: int
    rating: float
    comment: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True