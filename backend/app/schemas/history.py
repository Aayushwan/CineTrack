from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, Union
from datetime import datetime

# --- Request Schemas ---

class HistoryCreate(BaseModel):
    # Strictly matching the Supabase Database Columns
    media_id: str
    media_type: str
    title: str
    poster_path: Optional[str] = None
    duration_watched_seconds: Optional[int] = None
    watched_at: Optional[datetime] = None

    # This prevents crashes if Flutter accidentally sends extra data 
    model_config = ConfigDict(extra="ignore")


class EpisodeProgressUpdate(BaseModel):
    show_id: int = Field(..., alias="showId")
    title: str
    season: str
    total_episodes: int = Field(..., alias="totalEpisodes", ge=1)
    increment: int = Field(1, ge=1)

    model_config = ConfigDict(populate_by_name=True, extra="ignore")


# --- Response Schemas ---

class WatchHistoryItemResponse(BaseModel):
    id: int
    title: str
    subtitle: Optional[str] = None
    type: str
    poster: str
    watchedDate: str
    watchedTime: str
    userRating: float

    model_config = ConfigDict(from_attributes=True)


class ShowProgressResponse(BaseModel):
    title: str
    watchedEpisodes: int
    totalEpisodes: int

    model_config = ConfigDict(from_attributes=True)


class ProfileStatsPeriod(BaseModel):
    screenTime: str
    moviesCount: str
    episodesCount: str


class ProfileAnalyticsResponse(BaseModel):
    thisMonth: ProfileStatsPeriod
    allTime: ProfileStatsPeriod