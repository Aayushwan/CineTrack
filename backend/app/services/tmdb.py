# backend/app/services/tmdb.py
import httpx
from typing import Optional, Any
from fastapi import HTTPException, status
from app.core.config import settings

TMDB_BASE_URL = "https://api.themoviedb.org/3"


async def tmdb_get_request(endpoint: str, params: Optional[dict[str, Any]] = None) -> dict[str, Any]:
    """Utility helper for making async GET requests to TMDB."""
    query_params: dict[str, Any] = params.copy() if params else {}
    query_params["api_key"] = settings.TMDB_API_KEY
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(f"{TMDB_BASE_URL}{endpoint}", params=query_params)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"TMDB API error: {e.response.text}"
            )
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {str(e)}"
            )


async def get_trending_movies(page: int = 1):
    """Fetch daily trending movies."""
    return await tmdb_get_request("/trending/movie/day", {"page": page})


async def search_multi(query: str, page: int = 1):
    """Search TMDB across Movies, TV Shows, and Persons (actors/crew)."""
    return await tmdb_get_request("/search/multi", {"query": query, "page": page, "include_adult": False})


async def search_movies(query: str, page: int = 1):
    """Search specifically for movies."""
    return await tmdb_get_request("/search/movie", {"query": query, "page": page})


async def search_tv(query: str, page: int = 1):
    """Search specifically for TV shows."""
    return await tmdb_get_request("/search/tv", {"query": query, "page": page})


async def search_person(query: str, page: int = 1):
    """Search specifically for persons (actors, directors, crew)."""
    return await tmdb_get_request("/search/person", {"query": query, "page": page})


async def get_movie_details(movie_id: int):
    """Fetch detailed movie metadata including trailers and cast."""
    return await tmdb_get_request(f"/movie/{movie_id}", {"append_to_response": "videos,credits"})