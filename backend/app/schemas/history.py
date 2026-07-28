# app/schemas/history.py
from pydantic import BaseModel
from typing import Optional

class HistoryCreate(BaseModel):
    movie_id: int
    media_type: str  # "movie" or "tv"
    title: str
    subtitle: Optional[str] = None
    poster_path: Optional[str] = None
    user_rating: Optional[float] = None
    runtime_minutes: Optional[int] = 120

class EpisodeProgressUpdate(BaseModel):
    show_id: int
    title: str
    season: str
    total_episodes: int
    increment: int = 1