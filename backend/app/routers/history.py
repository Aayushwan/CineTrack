from datetime import datetime, timedelta, timezone
from typing import Any, Optional, Sequence

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.history import ShowProgress, WatchHistory
from app.models.user import User
from app.schemas.history import (
    EpisodeProgressUpdate,
    HistoryCreate,
    ShowHistoryCreate,
)

router = APIRouter(
    prefix="/user",
    tags=["User Activity & History"],
)

IST = timezone(timedelta(hours=5, minutes=30))


def _parse_show_id(media_id: str) -> int:
    try:
        return int(media_id)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="TV show media_id must be numeric",
        ) from exc


def _format_ist_date(
    value: Optional[datetime],
    format_string: str,
) -> str:
    if value is None:
        return ""

    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)

    return value.astimezone(IST).strftime(format_string)


async def _get_watched_episode_keys(
    db: AsyncSession,
    user_id: int,
    show_id: int,
) -> set[tuple[int, int]]:
    result = await db.scalars(
        select(WatchHistory).where(
            WatchHistory.user_id == user_id,
            WatchHistory.media_id == str(show_id),
            WatchHistory.media_type == "tv",
            WatchHistory.season_number.is_not(None),
            WatchHistory.episode_number.is_not(None),
        )
    )

    return {
        (
            history_item.season_number,
            history_item.episode_number,
        )
        for history_item in result.all()
        if history_item.season_number is not None
        and history_item.episode_number is not None
    }


def _get_next_episode_from_history(
    watched_keys: set[tuple[int, int]],
) -> tuple[int, int]:
    if not watched_keys:
        return 1, 1

    last_season, last_episode = max(watched_keys)
    return last_season, last_episode + 1


async def _sync_show_progress(
    db: AsyncSession,
    *,
    user_id: int,
    show_id: int,
    title: Optional[str] = None,
    total_episodes: Optional[int] = None,
    backdrop_path: Optional[str] = None,
) -> Optional[ShowProgress]:
    watched_keys = await _get_watched_episode_keys(
        db,
        user_id,
        show_id,
    )

    watched_count = len(watched_keys)

    result = await db.scalars(
        select(ShowProgress)
        .where(
            ShowProgress.user_id == user_id,
            ShowProgress.show_id == show_id,
        )
        .order_by(ShowProgress.id.asc())
    )

    records = list(result.all())
    record = records[0] if records else None

    # Remove legacy duplicate rows that stored progress per season.
    for duplicate in records[1:]:
        await db.delete(duplicate)

    if record is None:
        if watched_count == 0:
            return None

        latest_season = max(
            (
                season_number
                for season_number, _ in watched_keys
            ),
            default=1,
        )

        record = ShowProgress(
            user_id=user_id,
            show_id=show_id,
            title=title or "Unknown Show",
            season=f"Season {latest_season}",
            watched_episodes=watched_count,
            total_episodes=max(
                total_episodes or watched_count,
                watched_count,
            ),
            backdrop_path=backdrop_path,
        )

        db.add(record)
        return record

    latest_season = max(
        (
            season_number
            for season_number, _ in watched_keys
        ),
        default=1,
    )

    record.watched_episodes = watched_count
    record.total_episodes = max(
        total_episodes
        or record.total_episodes
        or watched_count,
        watched_count,
    )
    record.season = f"Season {latest_season}"

    if title:
        record.title = title

    if backdrop_path:
        record.backdrop_path = backdrop_path

    return record


# -----------------------------------------------------------------------------
# Watch history
# -----------------------------------------------------------------------------


@router.post(
    "/history",
    status_code=status.HTTP_201_CREATED,
)
async def log_watch_history(
    item: HistoryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    media_type = item.media_type.strip().lower()

    if media_type not in {"movie", "tv"}:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="media_type must be either movie or tv",
        )

    watched_time = (
        item.watched_at
        if item.watched_at is not None
        else datetime.now(timezone.utc)
    )

    is_episode = (
        media_type == "tv"
        and item.season_number is not None
        and item.episode_number is not None
    )

    show_id: Optional[int] = None

    if media_type == "tv":
        show_id = _parse_show_id(item.media_id)

    if is_episode:
        assert show_id is not None

        duplicate_result = await db.scalars(
            select(WatchHistory).where(
                WatchHistory.user_id == current_user.id,
                WatchHistory.media_id == item.media_id,
                WatchHistory.media_type == "tv",
                WatchHistory.season_number
                == item.season_number,
                WatchHistory.episode_number
                == item.episode_number,
            )
        )

        existing = duplicate_result.first()

        if existing is not None:
            await _sync_show_progress(
                db,
                user_id=current_user.id,
                show_id=show_id,
                title=item.title,
                total_episodes=item.total_episodes,
                backdrop_path=(
                    item.backdrop_path
                    or item.poster_path
                ),
            )

            await db.commit()

            return {
                "message": "Episode already logged",
                "id": existing.id,
                "already_logged": True,
            }

    new_entry = WatchHistory(
        user_id=current_user.id,
        media_id=item.media_id,
        media_type=media_type,
        title=item.title,
        poster_path=item.poster_path,
        duration_watched_seconds=(
            item.duration_watched_seconds
        ),
        watched_at=watched_time,
        season_number=item.season_number,
        episode_number=item.episode_number,
    )

    db.add(new_entry)
    await db.flush()

    if is_episode and show_id is not None:
        await _sync_show_progress(
            db,
            user_id=current_user.id,
            show_id=show_id,
            title=item.title,
            total_episodes=item.total_episodes,
            backdrop_path=(
                item.backdrop_path
                or item.poster_path
            ),
        )

    await db.commit()
    await db.refresh(new_entry)

    return {
        "message": "Logged successfully",
        "id": new_entry.id,
        "already_logged": False,
    }


@router.post(
    "/history/show",
    status_code=status.HTTP_201_CREATED,
)
async def log_entire_show_history(
    item: ShowHistoryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    show_id = _parse_show_id(item.media_id)

    watched_time = (
        item.watched_at
        if item.watched_at is not None
        else datetime.now(timezone.utc)
    )

    existing_keys = await _get_watched_episode_keys(
        db,
        current_user.id,
        show_id,
    )

    supplied_keys: set[tuple[int, int]] = set()
    added_count = 0

    for episode in item.episodes:
        key = (
            episode.season_number,
            episode.episode_number,
        )

        # Ignore duplicate episodes in the request.
        if key in supplied_keys:
            continue

        supplied_keys.add(key)

        # Do not create duplicate history rows.
        if key in existing_keys:
            continue

        db.add(
            WatchHistory(
                user_id=current_user.id,
                media_id=item.media_id,
                media_type="tv",
                title=item.title,
                poster_path=item.poster_path,
                duration_watched_seconds=(
                    episode.runtime * 60
                ),
                watched_at=watched_time,
                season_number=episode.season_number,
                episode_number=episode.episode_number,
            )
        )

        existing_keys.add(key)
        added_count += 1

    await db.flush()

    await _sync_show_progress(
        db,
        user_id=current_user.id,
        show_id=show_id,
        title=item.title,
        total_episodes=item.total_episodes,
        backdrop_path=(
            item.backdrop_path
            or item.poster_path
        ),
    )

    await db.commit()

    watched_count = len(existing_keys)

    return {
        "message": "Show episodes logged successfully",
        "episodes_added": added_count,
        "watchedEpisodes": watched_count,
        "totalEpisodes": item.total_episodes,
        "completed": (
            watched_count >= item.total_episodes
        ),
    }


@router.get("/history")
async def get_watch_history(
    media_type: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(WatchHistory).where(
        WatchHistory.user_id == current_user.id
    )

    if media_type:
        normalized_type = media_type.strip().lower()

        if normalized_type not in {"movie", "tv"}:
            raise HTTPException(
                status_code=(
                    status.HTTP_422_UNPROCESSABLE_ENTITY
                ),
                detail=(
                    "media_type must be either movie or tv"
                ),
            )

        stmt = stmt.where(
            WatchHistory.media_type == normalized_type
        )

    stmt = stmt.order_by(
        WatchHistory.watched_at.desc(),
        WatchHistory.id.desc(),
    )

    result = await db.scalars(stmt)
    history = result.all()

    return [
        {
            # Kept as media_id for compatibility with the
            # existing Flutter navigation code.
            "id": history_item.media_id,
            "media_id": history_item.media_id,
            "movie_id": history_item.media_id,
            "history_id": history_item.id,
            "title": history_item.title,
            "movie_title": history_item.title,
            "subtitle": (
                f"S{history_item.season_number} • "
                f"E{history_item.episode_number}"
                if history_item.season_number is not None
                and history_item.episode_number is not None
                else None
            ),
            "season_number":
                history_item.season_number,
            "episode_number":
                history_item.episode_number,
            "media_type": history_item.media_type,
            "type": (
                "Movie"
                if history_item.media_type == "movie"
                else "Show"
            ),
            "poster": (
                "https://image.tmdb.org/t/p/w500"
                f"{history_item.poster_path}"
                if history_item.poster_path
                and not history_item.poster_path.startswith(
                    "http"
                )
                else (history_item.poster_path or "")
            ),
            "poster_path": history_item.poster_path,
            "watched_at": (
                history_item.watched_at.isoformat()
                if history_item.watched_at
                else None
            ),
            "watchedDate": _format_ist_date(
                history_item.watched_at,
                "%b %d, %Y",
            ),
            "watchedTime": _format_ist_date(
                history_item.watched_at,
                "%I:%M %p",
            ),
            "userRating": 0.0,
        }
        for history_item in history
    ]


@router.delete(
    "/history/{history_id}",
    status_code=status.HTTP_200_OK,
)
async def remove_watch_history(
    history_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.scalars(
        select(WatchHistory).where(
            WatchHistory.id == history_id,
            WatchHistory.user_id == current_user.id,
        )
    )

    history_item = result.first()

    # Compatibility fallback for old Flutter code that sends
    # media_id instead of history_id.
    if history_item is None:
        fallback_result = await db.scalars(
            select(WatchHistory)
            .where(
                WatchHistory.user_id
                == current_user.id,
                WatchHistory.media_id
                == str(history_id),
            )
            .order_by(
                WatchHistory.watched_at.desc(),
                WatchHistory.id.desc(),
            )
        )

        history_item = fallback_result.first()

    if history_item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="History log not found",
        )

    show_id: Optional[int] = None

    if (
        history_item.media_type == "tv"
        and history_item.season_number is not None
        and history_item.episode_number is not None
    ):
        try:
            show_id = int(history_item.media_id)
        except (TypeError, ValueError):
            show_id = None

    await db.delete(history_item)
    await db.flush()

    if show_id is not None:
        await _sync_show_progress(
            db,
            user_id=current_user.id,
            show_id=show_id,
        )

    await db.commit()

    return {
        "detail": "History log removed successfully",
    }


# -----------------------------------------------------------------------------
# Show progress
# -----------------------------------------------------------------------------


@router.get("/progress/shows")
async def get_show_progress(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.scalars(
        select(ShowProgress)
        .where(
            ShowProgress.user_id == current_user.id,
            ShowProgress.watched_episodes > 0,
        )
        .order_by(
            ShowProgress.updated_at.desc(),
            ShowProgress.id.desc(),
        )
    )

    progress_items = result.all()
    response: list[dict[str, Any]] = []

    for progress in progress_items:
        watched_keys = await _get_watched_episode_keys(
            db,
            current_user.id,
            progress.show_id,
        )

        watched_count = len(watched_keys)

        if progress.watched_episodes != watched_count:
            progress.watched_episodes = watched_count

        next_season, next_episode = (
            _get_next_episode_from_history(watched_keys)
        )

        response.append(
            {
                "show_id": progress.show_id,
                "title": progress.title,
                "season": progress.season,
                "watchedEpisodes": watched_count,
                "totalEpisodes":
                    progress.total_episodes,
                "backdrop_path":
                    progress.backdrop_path,
                "nextSeasonNumber": next_season,
                "nextEpisodeNumber": next_episode,
                "nextEpisodeRuntime": 45,
                "completed": (
                    progress.total_episodes > 0
                    and watched_count
                    >= progress.total_episodes
                ),
            }
        )

    await db.commit()

    return response


@router.get("/progress/shows/{show_id}")
async def get_specific_show_progress(
    show_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    watched_keys = await _get_watched_episode_keys(
        db,
        current_user.id,
        show_id,
    )

    return [
        {
            "season_number": season_number,
            "episode_number": episode_number,
        }
        for season_number, episode_number in sorted(
            watched_keys
        )
    ]


@router.delete(
    "/progress/shows/{show_id}",
    status_code=status.HTTP_200_OK,
)
async def remove_show_from_history_and_progress(
    show_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await db.execute(
        delete(WatchHistory).where(
            WatchHistory.user_id == current_user.id,
            WatchHistory.media_id == str(show_id),
            WatchHistory.media_type == "tv",
        )
    )

    await db.execute(
        delete(ShowProgress).where(
            ShowProgress.user_id == current_user.id,
            ShowProgress.show_id == show_id,
        )
    )

    await db.commit()

    return {
        "detail": (
            "Show history and progress removed "
            "successfully"
        ),
    }


@router.post("/progress/episode")
async def update_show_progress(
    progress: EpisodeProgressUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.scalars(
        select(ShowProgress)
        .where(
            ShowProgress.user_id == current_user.id,
            ShowProgress.show_id == progress.show_id,
        )
        .order_by(ShowProgress.id.asc())
    )

    records = list(result.all())
    record = records[0] if records else None

    for duplicate in records[1:]:
        await db.delete(duplicate)

    if record is None:
        record = ShowProgress(
            user_id=current_user.id,
            show_id=progress.show_id,
            title=progress.title,
            season=progress.season,
            watched_episodes=min(
                progress.increment,
                progress.total_episodes,
            ),
            total_episodes=progress.total_episodes,
        )

        db.add(record)
    else:
        current_episodes = (
            record.watched_episodes or 0
        )

        record.title = progress.title
        record.season = progress.season
        record.total_episodes = max(
            progress.total_episodes,
            current_episodes,
        )
        record.watched_episodes = min(
            current_episodes + progress.increment,
            record.total_episodes,
        )

    await db.commit()
    await db.refresh(record)

    return {
        "show_id": record.show_id,
        "title": record.title,
        "season": record.season,
        "watchedEpisodes": record.watched_episodes,
        "totalEpisodes": record.total_episodes,
        "completed": (
            record.watched_episodes
            >= record.total_episodes
        ),
    }


@router.get("/progress/continue-watching")
async def get_continue_watching(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.scalars(
        select(ShowProgress)
        .where(
            ShowProgress.user_id == current_user.id,
            ShowProgress.watched_episodes > 0,
            ShowProgress.watched_episodes
            < ShowProgress.total_episodes,
        )
        .order_by(
            ShowProgress.updated_at.desc(),
            ShowProgress.id.desc(),
        )
        .limit(10)
    )

    progress_items = result.all()
    response: list[dict[str, Any]] = []

    for progress in progress_items:
        watched_keys = await _get_watched_episode_keys(
            db,
            current_user.id,
            progress.show_id,
        )

        watched_count = len(watched_keys)

        if watched_count == 0:
            progress.watched_episodes = 0
            continue

        progress.watched_episodes = watched_count

        if watched_count >= progress.total_episodes:
            continue

        next_season, next_episode = (
            _get_next_episode_from_history(watched_keys)
        )

        response.append(
            {
                "show_id": progress.show_id,
                "title": progress.title,
                "season": progress.season,
                "watchedEpisodes": watched_count,
                "totalEpisodes":
                    progress.total_episodes,
                "backdrop_path":
                    progress.backdrop_path,
                "nextSeasonNumber": next_season,
                "nextEpisodeNumber": next_episode,
                "nextEpisodeRuntime": 45,
                "completed": False,
            }
        )

    await db.commit()

    return response


# -----------------------------------------------------------------------------
# Profile analytics
# -----------------------------------------------------------------------------


@router.get("/profile/stats")
async def get_profile_analytics(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.scalars(
        select(WatchHistory).where(
            WatchHistory.user_id == current_user.id
        )
    )

    all_history = list(result.all())
    now = datetime.now(IST)

    month_history: list[WatchHistory] = []

    for history_item in all_history:
        watched_at = history_item.watched_at

        if watched_at is None:
            continue

        if watched_at.tzinfo is None:
            watched_at = watched_at.replace(
                tzinfo=timezone.utc
            )

        local_date = watched_at.astimezone(IST)

        if (
            local_date.year == now.year
            and local_date.month == now.month
        ):
            month_history.append(history_item)

    def calculate_stats(
        entries: Sequence[Any],
    ) -> dict[str, str]:
        total_seconds = sum(
            getattr(
                entry,
                "duration_watched_seconds",
                None,
            )
            or 0
            for entry in entries
        )

        movie_entries = [
            entry
            for entry in entries
            if str(
                getattr(entry, "media_type", "")
            ).lower()
            == "movie"
        ]

        show_entries = [
            entry
            for entry in entries
            if str(
                getattr(entry, "media_type", "")
            ).lower()
            == "tv"
        ]

        movie_seconds = sum(
            getattr(
                entry,
                "duration_watched_seconds",
                None,
            )
            or 0
            for entry in movie_entries
        )

        show_seconds = sum(
            getattr(
                entry,
                "duration_watched_seconds",
                None,
            )
            or 0
            for entry in show_entries
        )

        series_ids = {
            str(getattr(entry, "media_id", ""))
            for entry in show_entries
        }

        def format_time(total_minutes: int) -> str:
            if total_minutes <= 0:
                return "0h 0m"

            hours = total_minutes // 60
            remaining_minutes = total_minutes % 60
            days = hours // 24
            remaining_hours = hours % 24

            if days > 0:
                return f"{days}d {remaining_hours}h"

            return (
                f"{hours}h {remaining_minutes}m"
            )

        return {
            "totalScreenTime": format_time(
                total_seconds // 60
            ),
            "movieScreenTime": format_time(
                movie_seconds // 60
            ),
            "showScreenTime": format_time(
                show_seconds // 60
            ),
            "moviesCount": str(len(movie_entries)),
            "seriesCount": str(len(series_ids)),
        }

    return {
        "thisMonth": calculate_stats(month_history),
        "allTime": calculate_stats(all_history),
    }