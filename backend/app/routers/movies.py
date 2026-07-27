from fastapi import APIRouter, HTTPException, status
import httpx
from app.core.config import settings
from app.core.redis import get_cache, set_cache

router = APIRouter(prefix="/movies", tags=["Movies"])

TMDB_BASE_URL = "https://api.themoviedb.org/3"

# TMDB requires a valid User-Agent header to prevent blocking default python/httpx clients
HEADERS = {
    "User-Agent": "CineTrackApp/1.0 (Development)",
    "Accept": "application/json",
}

@router.get("/trending")
async def get_trending_movies(page: int = 1):
    cache_key = f"movies:trending:page:{page}"

    # 1. Try serving from Redis cache
    cached_data = await get_cache(cache_key)
    if cached_data:
        return cached_data

    if not settings.TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API Key is not configured."
        )

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        try:
            response = await client.get(
                f"{TMDB_BASE_URL}/trending/movie/day",
                params={"api_key": settings.TMDB_API_KEY, "page": page},
                headers=HEADERS,
            )
            if response.status_code != 200:
                print(f"❌ TMDB Error ({response.status_code}): {response.text}")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            # 2. Store in Redis cache for 1 hour (3600 seconds)
            await set_cache(cache_key, data, expire_seconds=3600)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            print(f"❌ Network Exception connecting to TMDB: {exc}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )


@router.get("/search")
async def search_movies(query: str, page: int = 1):
    cache_key = f"movies:search:query:{query.lower().strip()}:page:{page}"

    # 1. Try serving from Redis cache
    cached_data = await get_cache(cache_key)
    if cached_data:
        return cached_data

    if not settings.TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API Key is not configured."
        )

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        try:
            response = await client.get(
                f"{TMDB_BASE_URL}/search/movie",
                params={"api_key": settings.TMDB_API_KEY, "query": query, "page": page},
                headers=HEADERS,
            )
            if response.status_code != 200:
                print(f"❌ TMDB Error ({response.status_code}): {response.text}")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            # 2. Store in Redis cache for 30 minutes (1800 seconds)
            await set_cache(cache_key, data, expire_seconds=1800)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            print(f"❌ Network Exception connecting to TMDB: {exc}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )


@router.get("/{movie_id}")
async def get_movie_details(movie_id: int):
    cache_key = f"movies:details:{movie_id}"

    # 1. Try serving from Redis cache
    cached_data = await get_cache(cache_key)
    if cached_data:
        return cached_data

    if not settings.TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API Key is not configured."
        )

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        try:
            response = await client.get(
                f"{TMDB_BASE_URL}/movie/{movie_id}",
                params={
                    "api_key": settings.TMDB_API_KEY,
                    "append_to_response": "credits,videos"
                },
                headers=HEADERS,
            )
            if response.status_code != 200:
                print(f"❌ TMDB Error ({response.status_code}): {response.text}")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            # 2. Store in Redis cache for 12 hours (43200 seconds)
            await set_cache(cache_key, data, expire_seconds=43200)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            print(f"❌ Network Exception connecting to TMDB: {exc}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )