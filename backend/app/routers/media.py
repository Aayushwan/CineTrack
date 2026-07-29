# backend/app/routers/media.py
import asyncio
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


@router.get("/discover", summary="Discover Media by Category")
async def discover_media(category: str = "trending", page: int = 1):
    cache_key = f"movies:discover:v2:cat:{category}:page:{page}"

    # Try cache first
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

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        try:
            # -------------------------------------------------------------
            # Special Trakt.tv-style Combined Releases Feed (Movies + TV)
            # -------------------------------------------------------------
            if category == "releases":
                params = {"api_key": settings.TMDB_API_KEY, "page": page}
                
                # Fetch movies and TV shows concurrently
                movie_res, tv_res = await asyncio.gather(
                    client.get(f"{TMDB_BASE_URL}/movie/now_playing", params=params, headers=HEADERS),
                    client.get(f"{TMDB_BASE_URL}/tv/on_the_air", params=params, headers=HEADERS),
                    return_exceptions=True
                )

                # Use isinstance for clean type narrowing
                movies = []
                if isinstance(movie_res, httpx.Response) and movie_res.status_code == 200:
                    movies = movie_res.json().get("results", [])

                tv_shows = []
                if isinstance(tv_res, httpx.Response) and tv_res.status_code == 200:
                    tv_shows = tv_res.json().get("results", [])

                combined = []

                # Format Movies
                for m in movies:
                    m["media_type"] = "movie"
                    m["release_date"] = m.get("release_date", "")
                    m["air_time"] = "5:30 PM • New"
                    combined.append(m)

                # Format TV Shows with Episode information
                for idx, tv in enumerate(tv_shows):
                    tv["media_type"] = "tv"
                    tv["release_date"] = tv.get("first_air_date", "")
                    tv["season_number"] = tv.get("season_number", 1)
                    tv["episode_number"] = tv.get("episode_number", (idx % 10) + 1)
                    tv["episode_name"] = tv.get("episode_name", f"Episode {tv['episode_number']}")
                    tv["air_time"] = f"{((idx * 2) % 10) + 6}:30 PM"
                    combined.append(tv)

                # Sort by popularity descending
                combined.sort(key=lambda x: x.get("popularity", 0), reverse=True)

                data = {
                    "page": page,
                    "results": combined,
                    "total_pages": 50
                }

            # -------------------------------------------------------------
            # Single-Category Endpoints (Anticipated, Popular, Trending)
            # -------------------------------------------------------------
            else:
                if category == "anticipated":
                    tmdb_endpoint = "/movie/upcoming"
                elif category == "popular":
                    tmdb_endpoint = "/movie/popular"
                else:  # default to 'trending'
                    tmdb_endpoint = "/trending/movie/day"

                response = await client.get(
                    f"{TMDB_BASE_URL}{tmdb_endpoint}",
                    params={"api_key": settings.TMDB_API_KEY, "page": page},
                    headers=HEADERS,
                )
                
                if response.status_code != 200:
                    print(f"❌ TMDB Error ({response.status_code}): {response.text}")
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"TMDB returned status {response.status_code}"
                    )
                
                data = response.json()

            # Cache the compiled response
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