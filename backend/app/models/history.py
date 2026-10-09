# backend/app/models/history.py
from __future__ import annotations

from datetime import datetime
from typing import Optional, TYPE_CHECKING

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base

if TYPE_CHECKING:
    from app.models.user import User


class WatchHistory(Base):
    __tablename__ = "watch_history"

    __table_args__ = (
        Index(
            "uq_watch_history_user_tv_episode",
            "user_id",
            "media_id",
            "season_number",
            "episode_number",
            unique=True,
            postgresql_where=text(
                "media_type = 'tv' "
                "AND season_number IS NOT NULL "
                "AND episode_number IS NOT NULL"
            ),
        ),
    )

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )

    media_id: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )

    media_type: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )

    title: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )

    poster_path: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    watched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    season_number: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
    )

    episode_number: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
    )

    duration_watched_seconds: Mapped[Optional[int]] = (
        mapped_column(
            Integer,
            nullable=True,
        )
    )

    user: Mapped["User"] = relationship(
        "User",
        back_populates="history",
    )


class ShowProgress(Base):
    __tablename__ = "show_progress"

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )

    show_id: Mapped[int] = mapped_column(
        nullable=False,
    )

    title: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )

    season: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )

    watched_episodes: Mapped[int] = mapped_column(
        default=0,
        nullable=False,
    )

    total_episodes: Mapped[int] = mapped_column(
        nullable=False,
    )

    backdrop_path: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    user: Mapped["User"] = relationship(
        "User",
        back_populates="show_progress",
    )