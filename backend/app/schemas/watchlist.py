# backend/app/schemas/watchlist.py
from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime

class WatchlistCreate(BaseModel):
    movie_id: int
    movie_title: str
    poster_path: Optional[str] = None
    status: str = "watchlist"
    media_type: str = "movie"  # 👈 Added "movie" or "tv"

class WatchlistResponse(BaseModel):
    id: int
    user_id: int
    movie_id: int
    movie_title: str
    poster_path: Optional[str] = None
    media_type: str  # 👈 Added "movie" or "tv"
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)