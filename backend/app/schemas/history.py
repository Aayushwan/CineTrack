from pydantic import BaseModel, ConfigDict, Field
from typing import Optional


# --- Request Schemas ---

class HistoryCreate(BaseModel):
    movie_id: int = Field(..., description="Media or TMDB ID")
    media_type: str = Field(..., description="'movie' or 'tv'")
    title: str
    subtitle: Optional[str] = None
    poster_path: Optional[str] = None
    user_rating: Optional[float] = Field(None, ge=0.0, le=10.0)
    runtime_minutes: Optional[int] = 120


class EpisodeProgressUpdate(BaseModel):
    show_id: int
    title: str
    season: str
    total_episodes: int = Field(..., ge=1)
    increment: int = Field(1, ge=1)


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