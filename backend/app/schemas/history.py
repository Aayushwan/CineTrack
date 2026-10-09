from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


# -----------------------------------------------------------------------------
# Request schemas
# -----------------------------------------------------------------------------


class HistoryCreate(BaseModel):
    media_id: str
    media_type: str
    title: str

    poster_path: Optional[str] = None
    backdrop_path: Optional[str] = None

    duration_watched_seconds: Optional[int] = Field(
        default=None,
        ge=0,
    )

    watched_at: Optional[datetime] = None

    season_number: Optional[int] = Field(
        default=None,
        ge=1,
    )

    episode_number: Optional[int] = Field(
        default=None,
        ge=1,
    )

    total_episodes: Optional[int] = Field(
        default=None,
        ge=1,
    )

    model_config = ConfigDict(
        extra="ignore",
    )


class ShowEpisodeCreate(BaseModel):
    season_number: int = Field(
        ge=1,
    )

    episode_number: int = Field(
        ge=1,
    )

    runtime: int = Field(
        default=45,
        ge=0,
    )

    model_config = ConfigDict(
        extra="ignore",
    )


class ShowHistoryCreate(BaseModel):
    media_id: str
    title: str

    poster_path: Optional[str] = None
    backdrop_path: Optional[str] = None

    total_episodes: int = Field(
        ge=1,
    )

    watched_at: Optional[datetime] = None

    episodes: List[ShowEpisodeCreate] = Field(
        min_length=1,
    )

    model_config = ConfigDict(
        extra="ignore",
    )


class EpisodeProgressUpdate(BaseModel):
    show_id: int = Field(
        ...,
        alias="showId",
        ge=1,
    )

    title: str
    season: str

    total_episodes: int = Field(
        ...,
        alias="totalEpisodes",
        ge=1,
    )

    increment: int = Field(
        default=1,
        ge=1,
    )

    model_config = ConfigDict(
        populate_by_name=True,
        extra="ignore",
    )


# -----------------------------------------------------------------------------
# Response schemas
# -----------------------------------------------------------------------------


class WatchHistoryItemResponse(BaseModel):
    id: str
    media_id: str
    history_id: int

    title: str
    subtitle: Optional[str] = None

    season_number: Optional[int] = None
    episode_number: Optional[int] = None

    media_type: str
    type: str

    poster: str
    poster_path: Optional[str] = None

    watched_at: Optional[datetime] = None
    watchedDate: str
    watchedTime: str

    userRating: float = 0.0

    model_config = ConfigDict(
        from_attributes=True,
    )


class ShowProgressResponse(BaseModel):
    show_id: int
    title: str
    season: str

    watchedEpisodes: int
    totalEpisodes: int

    backdrop_path: Optional[str] = None

    nextSeasonNumber: Optional[int] = None
    nextEpisodeNumber: Optional[int] = None
    nextEpisodeRuntime: Optional[int] = None

    completed: bool

    model_config = ConfigDict(
        from_attributes=True,
    )


class ProfileStatsPeriod(BaseModel):
    totalScreenTime: str
    movieScreenTime: str
    showScreenTime: str
    moviesCount: str
    seriesCount: str


class ProfileAnalyticsResponse(BaseModel):
    thisMonth: ProfileStatsPeriod
    allTime: ProfileStatsPeriod