# backend/app/routers/history.py
from datetime import datetime
from typing import List, Optional, Any
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.history import WatchHistory, ShowProgress
from app.models.user import User
from app.schemas.history import HistoryCreate, EpisodeProgressUpdate
from app.core.security import get_current_user 

router = APIRouter(prefix="/user", tags=["User Activity & History"])


@router.post("/history", status_code=status.HTTP_201_CREATED)
def log_watch_history(
    item: HistoryCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    new_entry = WatchHistory(
        user_id=current_user.id,
        movie_id=item.movie_id,
        media_type=item.media_type,
        title=item.title,
        subtitle=item.subtitle,
        poster_path=item.poster_path,
        user_rating=item.user_rating,
        runtime_minutes=item.runtime_minutes,
        watched_at=datetime.utcnow()
    )
    db.add(new_entry)
    db.commit()
    db.refresh(new_entry)
    return {"message": "Logged successfully", "id": getattr(new_entry, "id")}


@router.get("/history")
def get_watch_history(
    media_type: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(WatchHistory).filter(WatchHistory.user_id == current_user.id)
    
    if media_type and media_type.lower() in ["movie", "tv"]:
        query = query.filter(WatchHistory.media_type == media_type.lower())

    history = query.order_by(WatchHistory.watched_at.desc()).all()
    
    return [
        {
            "id": getattr(h, "movie_id"),
            "title": getattr(h, "title"),
            "subtitle": getattr(h, "subtitle"),
            "type": "Movie" if str(getattr(h, "media_type", "")) == "movie" else "Show",
            "poster": f"https://image.tmdb.org/t/p/w500{getattr(h, 'poster_path')}" if getattr(h, "poster_path") else "",
            "watchedDate": getattr(h, "watched_at").strftime("%b %d, %Y") if getattr(h, "watched_at") else "",
            "watchedTime": getattr(h, "watched_at").strftime("%I:%M %p") if getattr(h, "watched_at") else "",
            "userRating": getattr(h, "user_rating") or 0.0,
        }
        for h in history
    ]


@router.post("/progress/episode")
def update_show_progress(
    progress: EpisodeProgressUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    record = db.query(ShowProgress).filter(
        ShowProgress.user_id == current_user.id,
        ShowProgress.show_id == progress.show_id,
        ShowProgress.season == progress.season
    ).first()

    if not record:
        record = ShowProgress(
            user_id=current_user.id,
            show_id=progress.show_id,
            title=progress.title,
            season=progress.season,
            watched_episodes=min(progress.increment, progress.total_episodes),
            total_episodes=progress.total_episodes,
        )
        db.add(record)
    else:
        current_episodes = int(getattr(record, "watched_episodes", 0))
        new_count = min(current_episodes + progress.increment, progress.total_episodes)
        setattr(record, "watched_episodes", new_count)

    db.commit()
    return {
        "title": getattr(record, "title"),
        "watchedEpisodes": getattr(record, "watched_episodes"),
        "totalEpisodes": getattr(record, "total_episodes")
    }


@router.get("/profile/stats")
def get_profile_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    all_history = db.query(WatchHistory).filter(WatchHistory.user_id == current_user.id).all()
    
    now = datetime.utcnow()
    month_history = [
        h for h in all_history 
        if getattr(h, "watched_at") and getattr(h, "watched_at").year == now.year and getattr(h, "watched_at").month == now.month
    ]

    def calculate_stats(entries: List[Any]):
        total_minutes = sum(int(getattr(e, "runtime_minutes", 120) or 120) for e in entries)
        movies_count = len([e for e in entries if str(getattr(e, "media_type", "")) == "movie"])
        episodes_count = len([e for e in entries if str(getattr(e, "media_type", "")) == "tv"])
        
        hours = total_minutes // 60
        mins = total_minutes % 60
        days = hours // 24
        rem_hours = hours % 24
        
        screen_time_str = f"{days}d {rem_hours}h" if days > 0 else f"{hours}h {mins}m"

        return {
            "screenTime": screen_time_str,
            "moviesCount": str(movies_count),
            "episodesCount": str(episodes_count),
        }

    return {
        "thisMonth": calculate_stats(month_history),
        "allTime": calculate_stats(all_history),
    }