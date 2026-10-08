from datetime import datetime, timezone, timedelta
from typing import List, Optional, Any, Sequence
from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.history import WatchHistory, ShowProgress
from app.models.user import User
from app.schemas.history import HistoryCreate, EpisodeProgressUpdate
from app.core.security import get_current_user 

router = APIRouter(prefix="/user", tags=["User Activity & History"])

# Indian Standard Time configuration
IST = timezone(timedelta(hours=5, minutes=30))

@router.post("/history", status_code=status.HTTP_201_CREATED)
async def log_watch_history(
    item: HistoryCreate, 
    db: AsyncSession = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    watched_time = item.watched_at if item.watched_at else datetime.now(timezone.utc)
    
    new_entry = WatchHistory(
        user_id=current_user.id,
        media_id=item.media_id,
        media_type=item.media_type,
        title=item.title,
        poster_path=item.poster_path,
        duration_watched_seconds=item.duration_watched_seconds,
        watched_at=watched_time
    )
    
    db.add(new_entry)
    await db.commit()
    await db.refresh(new_entry)
    
    return {"message": "Logged successfully", "id": getattr(new_entry, "id", None)}


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
    
    # 👇 Fixed the type hint here to accept Optional[datetime]
    def format_ist_date(dt: Optional[datetime], fmt_str: str) -> str:
        if not dt:
            return ""
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(IST).strftime(fmt_str)
    
    return [
        {
            "id": h.media_id,
            "history_id": h.id, 
            "title": h.title,
            "subtitle": None, 
            "type": "Movie" if str(h.media_type or "").lower() == "movie" else "Show",
            "poster": f"https://image.tmdb.org/t/p/w500{h.poster_path}" if h.poster_path and not h.poster_path.startswith("http") else (h.poster_path or ""),
            "watchedDate": format_ist_date(h.watched_at, "%b %d, %Y"),
            "watchedTime": format_ist_date(h.watched_at, "%I:%M %p"),
            "userRating": 0.0, 
        }
        for h in history
    ]


@router.delete("/history/{history_id}", status_code=status.HTTP_200_OK)
async def remove_watch_history(
    history_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    stmt = select(WatchHistory).where(
        WatchHistory.id == history_id,
        WatchHistory.user_id == current_user.id
    )
    result = await db.scalars(stmt)
    history_item = result.first()

    if not history_item:
        fallback_stmt = select(WatchHistory).where(WatchHistory.user_id == current_user.id)
        all_user_history = await db.scalars(fallback_stmt)
        for item in all_user_history.all():
            if str(item.media_id) == str(history_id):
                history_item = item
                break
        
        if not history_item:
            raise HTTPException(status_code=404, detail="History log not found")

    await db.delete(history_item)
    await db.commit()
    
    return {"detail": "History log removed successfully"}


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
    
    now = datetime.now(IST)
    month_history = []
    
    for h in all_history:
        if h.watched_at:
            dt = h.watched_at
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            local_dt = dt.astimezone(IST)
            if local_dt.year == now.year and local_dt.month == now.month:
                month_history.append(h)

    def calculate_stats(entries: Sequence[Any]):
        total_seconds = sum(getattr(e, "duration_watched_seconds", None) or 7200 for e in entries)
        total_minutes = total_seconds // 60
        
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