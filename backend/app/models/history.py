# app/models/history.py
from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship

# Import Base from your db session setup
from app.db.session import Base 

class WatchHistory(Base):
    __tablename__ = "watch_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    movie_id = Column(Integer, nullable=False)
    media_type = Column(String, nullable=False)  # "movie" or "tv"
    title = Column(String, nullable=False)
    subtitle = Column(String, nullable=True)      # e.g., "S4 • E1: Case-Mukadma"
    poster_path = Column(String, nullable=True)
    
    user_rating = Column(Float, nullable=True)
    runtime_minutes = Column(Integer, default=120)
    watched_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="history")


class ShowProgress(Base):
    __tablename__ = "show_progress"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    show_id = Column(Integer, nullable=False)
    title = Column(String, nullable=False)
    season = Column(String, nullable=False)       # e.g., "Season 4"
    watched_episodes = Column(Integer, default=0)
    total_episodes = Column(Integer, nullable=False)
    backdrop_path = Column(String, nullable=True)
    
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="show_progress")