# backend/app/schemas/watchlist.py
from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime

class WatchlistCreate(BaseModel):
    movie_id: int
    movie_title: str
    poster_path: Optional[str] = None
    status: str = "watchlist"
    media_type: str = "movie"
    release_year: Optional[str] = None
    runtime: Optional[int] = None
    total_episodes: Optional[int] = None
    vote_average: Optional[float] = None

class WatchlistResponse(BaseModel):
    id: int
    user_id: int
    movie_id: int
    movie_title: str
    poster_path: Optional[str] = None
    media_type: str  
    status: str
    release_year: Optional[str] = None
    runtime: Optional[int] = None
    total_episodes: Optional[int] = None
    vote_average: Optional[float] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)