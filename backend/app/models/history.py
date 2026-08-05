from __future__ import annotations
from datetime import datetime
from typing import Optional, TYPE_CHECKING
from sqlalchemy import String, DateTime, ForeignKey, func, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base

if TYPE_CHECKING:
    from app.models.user import User


class WatchHistory(Base):
    __tablename__ = "watch_history"

    id: Mapped[int] = mapped_column(primary_key=True, index=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)

    movie_id: Mapped[int] = mapped_column("media_id", Integer, nullable=False)
    media_type: Mapped[str] = mapped_column(String, nullable=False)  # "movie" or "tv"
    title: Mapped[str] = mapped_column(String, nullable=False)
    poster_path: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    watched_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    user: Mapped[User] = relationship("User", back_populates="history")


class ShowProgress(Base):
    __tablename__ = "show_progress"

    id: Mapped[int] = mapped_column(primary_key=True, index=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)

    show_id: Mapped[int] = mapped_column(nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    season: Mapped[str] = mapped_column(String, nullable=False)
    watched_episodes: Mapped[int] = mapped_column(default=0)
    total_episodes: Mapped[int] = mapped_column(nullable=False)
    backdrop_path: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped[User] = relationship("User", back_populates="show_progress")