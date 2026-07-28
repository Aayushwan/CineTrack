# backend/app/routers/media.py
from fastapi import APIRouter, HTTPException, status
import httpx
from app.core.config import settings
from app.core.redis import get_cache, set_cache

# Router prefix MUST remain "/movies" so Flutter's ApiService matches seamlessly
router = APIRouter(prefix="/movies", tags=["Media & Search"])

TMDB_BASE_URL = "https://api.themoviedb.org/3"

HEADERS = {
    "User-Agent": "CineTrackApp/1.0 (Development)",
    "Accept": "application/json",
}


# =====================================================================
# 1. STATIC & SPECIFIC ROUTES (Must come first to prevent 422 errors)
# =====================================================================

@router.get("/trending")
async def get_trending_movies(page: int = 1):
    cache_key = f"movies:trending:page:{page}"

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
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            await set_cache(cache_key, data, expire_seconds=3600)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )


@router.get("/search", summary="Search Multi Media")
async def search_media(query: str, page: int = 1):
    cache_key = f"multisearch:v5:query:{query.lower().strip()}:page:{page}"

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
            # Calls /search/multi to fetch Movies, TV Shows, and Persons simultaneously
            response = await client.get(
                f"{TMDB_BASE_URL}/search/multi",
                params={
                    "api_key": settings.TMDB_API_KEY,
                    "query": query,
                    "page": page,
                    "include_adult": "false",
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


@router.get("/upcoming", summary="Get Upcoming Movies and Shows")
async def get_upcoming_media(page: int = 1):
    cache_key = f"movies:upcoming:page:{page}"

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
                f"{TMDB_BASE_URL}/movie/upcoming",
                params={"api_key": settings.TMDB_API_KEY, "page": page},
                headers=HEADERS,
            )
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            await set_cache(cache_key, data, expire_seconds=14400) # Cache for 4 hours
            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )

# Place this ABOVE @router.get("/{movie_id}") in backend/app/routers/media.py

# Place this ABOVE @router.get("/{movie_id}") in backend/app/routers/media.py

@router.get("/discover", summary="Discover Media by Category")
async def discover_media(category: str = "trending", page: int = 1):
    cache_key = f"movies:discover:cat:{category}:page:{page}"

    # Try cache first (if redis function exists)
    try:
        cached_data = await get_cache(cache_key)
        if cached_data:
            return cached_data
    except Exception:
        pass # Ignore cache failures gracefully

    if not settings.TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API Key is missing in .env file."
        )

    # Map categories to TMDB API endpoints
    if category == "releases":
        tmdb_endpoint = "/movie/now_playing"
    elif category == "anticipated":
        tmdb_endpoint = "/movie/upcoming"
    elif category == "popular":
        tmdb_endpoint = "/movie/popular"
    else:  # default to 'trending'
        tmdb_endpoint = "/trending/movie/day"

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        try:
            response = await client.get(
                f"{TMDB_BASE_URL}{tmdb_endpoint}",
                params={"api_key": settings.TMDB_API_KEY, "page": page},
                headers=HEADERS if 'HEADERS' in globals() else {"accept": "application/json"},
            )
            
            if response.status_code != 200:
                print(f"❌ TMDB Error ({response.status_code}): {response.text}")
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"TMDB returned status {response.status_code}"
                )
            
            data = response.json()
            try:
                await set_cache(cache_key, data, expire_seconds=3600)
            except Exception:
                pass

            return data

        except HTTPException:
            raise
        except Exception as exc:
            print(f"❌ Connection Error: {exc}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )

@router.get("/tv/{tv_id}", summary="Get TV Show Details")
async def get_tv_details(tv_id: int):
    cache_key = f"tv:details:{tv_id}"
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
                f"{TMDB_BASE_URL}/tv/{tv_id}",
                params={
                    "api_key": settings.TMDB_API_KEY,
                    "append_to_response": "credits,videos"
                },
                headers=HEADERS,
            )
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            await set_cache(cache_key, data, expire_seconds=43200)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )


@router.get("/person/{person_id}", summary="Get Person Details")
async def get_person_details(person_id: int):
    cache_key = f"person:details:{person_id}"
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
                f"{TMDB_BASE_URL}/person/{person_id}",
                params={
                    "api_key": settings.TMDB_API_KEY,
                    "append_to_response": "combined_credits"
                },
                headers=HEADERS,
            )
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            await set_cache(cache_key, data, expire_seconds=43200)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )


# =====================================================================
# 2. DYNAMIC CATCH-ALL ROUTE (Must be at the VERY BOTTOM)
# =====================================================================

@router.get("/{movie_id}", summary="Get Movie Details")
async def get_movie_details(movie_id: int):
    cache_key = f"movies:details:{movie_id}"

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
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            await set_cache(cache_key, data, expire_seconds=43200)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )