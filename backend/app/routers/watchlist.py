# backend/app/routers/watchlist.py
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.models.watchlist import Watchlist
from app.schemas.watchlist import WatchlistCreate, WatchlistResponse

router = APIRouter(prefix="/watchlist", tags=["Watchlist"])

@router.post("/", response_model=WatchlistResponse, status_code=status.HTTP_201_CREATED)
async def add_or_update_watchlist(
    item: WatchlistCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Add a movie or show to user watchlist or update its status (watchlist/favorite/watched)."""
    # Look up entry matching user_id, movie_id AND media_type
    query = select(Watchlist).where(
        Watchlist.user_id == current_user.id,
        Watchlist.movie_id == item.movie_id,
        Watchlist.media_type == item.media_type
    )
    result = await db.execute(query)
    existing_item = result.scalars().first()

    if existing_item:
        existing_item.status = item.status
        existing_item.movie_title = item.movie_title
        if item.poster_path:
            existing_item.poster_path = item.poster_path
        await db.commit()
        await db.refresh(existing_item)
        return existing_item

    new_item = Watchlist(
        user_id=current_user.id,
        movie_id=item.movie_id,
        movie_title=item.movie_title,
        poster_path=item.poster_path,
        media_type=item.media_type,  # 👈 Pass media_type ('movie' or 'tv')
        status=item.status
    )
    db.add(new_item)
    await db.commit()
    await db.refresh(new_item)
    return new_item

@router.get("/", response_model=List[WatchlistResponse])
async def get_user_watchlist(
    status_filter: Optional[str] = Query(None, alias="status"),
    media_type_filter: Optional[str] = Query(None, alias="media_type"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Retrieve saved media items for the current logged-in user."""
    query = select(Watchlist).where(Watchlist.user_id == current_user.id)
    
    if status_filter:
        query = query.where(Watchlist.status == status_filter)
    if media_type_filter:
        query = query.where(Watchlist.media_type == media_type_filter)

    result = await db.execute(query)
    return result.scalars().all()

@router.delete("/{movie_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_from_watchlist(
    movie_id: int,
    media_type: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Remove a movie or TV show from the user's saved list."""
    query = select(Watchlist).where(
        Watchlist.user_id == current_user.id,
        Watchlist.movie_id == movie_id
    )
    if media_type:
        query = query.where(Watchlist.media_type == media_type)

    result = await db.execute(query)
    items = result.scalars().all()

    if not items:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item not found in your watchlist"
        )

    for item in items:
        await db.delete(item)
    await db.commit()
    return None