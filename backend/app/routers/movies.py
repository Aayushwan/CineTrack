from fastapi import APIRouter, HTTPException, status
import httpx
from app.core.config import settings

router = APIRouter(prefix="/movies", tags=["Movies"])

TMDB_BASE_URL = "https://api.themoviedb.org/3"

# TMDB requires a valid User-Agent header to prevent blocking default python/httpx clients
HEADERS = {
    "User-Agent": "CineTrackApp/1.0 (Development)",
    "Accept": "application/json",
}

@router.get("/trending")
async def get_trending_movies(page: int = 1):
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
            return response.json()
        except Exception as exc:
            print(f"❌ Network Exception connecting to TMDB: {exc}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )

@router.get("/search")
async def search_movies(query: str, page: int = 1):
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
            return response.json()
        except Exception as exc:
            print(f"❌ Network Exception connecting to TMDB: {exc}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )

@router.get("/{movie_id}")
async def get_movie_details(movie_id: int):
    if not settings.TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API Key is not configured."
        )

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        try:
            response = await client.get(
                f"{TMDB_BASE_URL}/movie/{movie_id}",
                params={"api_key": settings.TMDB_API_KEY},
                headers=HEADERS,
            )
            if response.status_code != 200:
                print(f"❌ TMDB Error ({response.status_code}): {response.text}")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            return response.json()
        except Exception as exc:
            print(f"❌ Network Exception connecting to TMDB: {exc}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )