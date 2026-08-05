from datetime import datetime, timezone
from typing import List, Optional, Any, Sequence
from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.history import WatchHistory, ShowProgress
from app.models.user import User
from app.schemas.history import HistoryCreate, EpisodeProgressUpdate
from app.core.security import get_current_user 

router = APIRouter(prefix="/user", tags=["User Activity & History"])


@router.post("/history", status_code=status.HTTP_201_CREATED)
async def log_watch_history(
    item: HistoryCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    new_entry = WatchHistory(
        user_id=current_user.id,
        movie_id=item.movie_id,
        media_type=item.media_type,
        title=item.title,
        poster_path=item.poster_path,
        watched_at=datetime.now(timezone.utc)
    )
    db.add(new_entry)
    await db.commit()
    await db.refresh(new_entry)
    return {"message": "Logged successfully", "id": new_entry.id}


@router.get("/history")
async def get_watch_history(
    media_type: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    stmt = select(WatchHistory).where(WatchHistory.user_id == current_user.id)
    
    if media_type and media_type.lower() in ["movie", "tv"]:
        stmt = stmt.where(WatchHistory.media_type == media_type.lower())

    stmt = stmt.order_by(WatchHistory.watched_at.desc())
    
    result = await db.scalars(stmt)
    history = result.all()
    
    return [
        {
            "id": h.movie_id,
            "title": h.title,
            "subtitle": None,
            "type": "Movie" if str(h.media_type or "") == "movie" else "Show",
            "poster": f"https://image.tmdb.org/t/p/w500{h.poster_path}" if h.poster_path else "",
            "watchedDate": h.watched_at.strftime("%b %d, %Y") if h.watched_at else "",
            "watchedTime": h.watched_at.strftime("%I:%M %p") if h.watched_at else "",
            "userRating": 0.0,
        }
        for h in history
    ]


@router.post("/progress/episode")
async def update_show_progress(
    progress: EpisodeProgressUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    stmt = select(ShowProgress).where(
        ShowProgress.user_id == current_user.id,
        ShowProgress.show_id == progress.show_id,
        ShowProgress.season == progress.season
    )
    result = await db.scalars(stmt)
    record = result.first()

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
        current_episodes = record.watched_episodes or 0
        new_count = min(current_episodes + progress.increment, progress.total_episodes)
        record.watched_episodes = new_count

    await db.commit()
    return {
        "title": record.title,
        "watchedEpisodes": record.watched_episodes,
        "totalEpisodes": record.total_episodes
    }


@router.get("/profile/stats")
async def get_profile_analytics(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    stmt = select(WatchHistory).where(WatchHistory.user_id == current_user.id)
    result = await db.scalars(stmt)
    all_history = result.all()
    
    now = datetime.now(timezone.utc)
    month_history = [
        h for h in all_history 
        if h.watched_at and h.watched_at.year == now.year and h.watched_at.month == now.month
    ]

    def calculate_stats(entries: Sequence[Any]):
        total_minutes = len(entries) * 120
        movies_count = len([e for e in entries if str(e.media_type or "") == "movie"])
        episodes_count = len([e for e in entries if str(e.media_type or "") == "tv"])
        
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