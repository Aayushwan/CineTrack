# backend/app/models/watchlist.py
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, DateTime, func, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class Watchlist(Base):
    __tablename__ = "watchlists"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    movie_id: Mapped[int] = mapped_column(Integer, nullable=False)
    movie_title: Mapped[str] = mapped_column(String(255), nullable=False)
    poster_path: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    media_type: Mapped[str] = mapped_column(String(20), nullable=False, default="movie")  # 👈 Added "movie" or "tv"
    status: Mapped[str] = mapped_column(String(20), default="watchlist")  # "watchlist", "favorite", or "watched"
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "movie_id", "media_type", name="uq_user_movie_mediatype"),  # 👈 Allows same ID for movie vs tv
    )