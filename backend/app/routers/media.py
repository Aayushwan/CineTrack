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
async def get_trending_movies(page: int = 1, type: str = "movie"):
    media_type = type.lower() if type in ["movie", "tv", "all"] else "movie"
    cache_key = f"movies:trending:v3:type:{media_type}:page:{page}"

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
                f"{TMDB_BASE_URL}/trending/{media_type}/day",
                params={"api_key": settings.TMDB_API_KEY, "page": page},
                headers=HEADERS,
            )
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()

            for item in data.get("results", []):
                if "media_type" not in item or not item["media_type"]:
                    item["media_type"] = "tv" if "name" in item else "movie"

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
    cache_key = f"multisearch:v6:query:{query.lower().strip()}:page:{page}"

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
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()

            for item in data.get("results", []):
                if "media_type" not in item or not item["media_type"]:
                    item["media_type"] = "tv" if "name" in item else "movie"

            await set_cache(cache_key, data, expire_seconds=1800)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )


@router.get("/upcoming", summary="Get Upcoming Movies and Shows Calendar")
async def get_upcoming_media(page: int = 1):
    # 👇 Bumped to v5 to force Redis to fetch fresh data
    cache_key = f"calendar:upcoming:v5:page:{page}"

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
            # 👇 Added region="IN" to pull regional releases (like Drishyam 3)
            params = {"api_key": settings.TMDB_API_KEY, "page": page, "region": "IN"}
            
            movie_res, tv_res = await asyncio.gather(
                client.get(f"{TMDB_BASE_URL}/movie/upcoming", params=params, headers=HEADERS),
                client.get(f"{TMDB_BASE_URL}/tv/on_the_air", params=params, headers=HEADERS),
                return_exceptions=True
            )

            movies = movie_res.json().get("results", []) if isinstance(movie_res, httpx.Response) and movie_res.status_code == 200 else []
            tv_shows = tv_res.json().get("results", []) if isinstance(tv_res, httpx.Response) and tv_res.status_code == 200 else []

            combined = []

            for m in movies:
                m["media_type"] = "movie"
                m["calendar_date"] = m.get("release_date", "2099-12-31")
                combined.append(m)

            for tv in tv_shows:
                tv["media_type"] = "tv"
                tv["calendar_date"] = tv.get("first_air_date", "2099-12-31")
                tv["title"] = tv.get("name", "Unknown Show")
                combined.append(tv)

            combined.sort(key=lambda x: x.get("calendar_date", "2099-12-31"))

            data = {
                "page": page,
                "results": combined,
                "total_pages": 50
            }

            await set_cache(cache_key, data, expire_seconds=14400)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to build calendar: {exc}"
            )


@router.get("/discover", summary="Discover Media by Category")
async def discover_media(category: str = "trending", page: int = 1, type: str = "movie"):
    media_type = type.lower() if type in ["movie", "tv"] else "movie"
    # 👇 Bumped to v5
    cache_key = f"movies:discover:v5:cat:{category}:type:{media_type}:page:{page}"

    try:
        cached_data = await get_cache(cache_key)
        if cached_data:
            return cached_data
    except Exception:
        pass

    if not settings.TMDB_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TMDB API Key is missing in .env file."
        )

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        try:
            if category == "releases":
                # 👇 Added region="IN" here as well
                params = {"api_key": settings.TMDB_API_KEY, "page": page, "region": "IN"}
                
                movie_res, tv_res = await asyncio.gather(
                    client.get(f"{TMDB_BASE_URL}/movie/now_playing", params=params, headers=HEADERS),
                    client.get(f"{TMDB_BASE_URL}/tv/on_the_air", params=params, headers=HEADERS),
                    return_exceptions=True
                )

                movies = movie_res.json().get("results", []) if isinstance(movie_res, httpx.Response) and movie_res.status_code == 200 else []
                tv_shows = tv_res.json().get("results", []) if isinstance(tv_res, httpx.Response) and tv_res.status_code == 200 else []

                combined = []

                for m in movies:
                    m["media_type"] = "movie"
                    m["release_date"] = m.get("release_date", "")
                    m["calendar_date"] = m.get("release_date", "")
                    m["air_time"] = "5:30 PM • New"
                    combined.append(m)

                for idx, tv in enumerate(tv_shows):
                    tv["media_type"] = "tv"
                    tv["release_date"] = tv.get("first_air_date", "")
                    tv["calendar_date"] = tv.get("first_air_date", "")
                    tv["season_number"] = tv.get("season_number", 1)
                    tv["episode_number"] = tv.get("episode_number", (idx % 10) + 1)
                    tv["episode_name"] = tv.get("episode_name", f"Episode {tv['episode_number']}")
                    tv["title"] = tv.get("name", "Unknown Show")
                    tv["air_time"] = f"{((idx * 2) % 10) + 6}:30 PM"
                    combined.append(tv)

                combined.sort(key=lambda x: x.get("popularity", 0), reverse=True)

                data = {
                    "page": page,
                    "results": combined,
                    "total_pages": 50
                }

            else:
                if media_type == "tv":
                    if category == "anticipated":
                        tmdb_endpoint = "/tv/on_the_air"
                    elif category == "popular":
                        tmdb_endpoint = "/tv/popular"
                    else:
                        tmdb_endpoint = "/trending/tv/day"
                else:
                    if category == "anticipated":
                        tmdb_endpoint = "/movie/upcoming"
                    elif category == "popular":
                        tmdb_endpoint = "/movie/popular"
                    else:
                        tmdb_endpoint = "/trending/movie/day"

                response = await client.get(
                    f"{TMDB_BASE_URL}{tmdb_endpoint}",
                    params={"api_key": settings.TMDB_API_KEY, "page": page, "region": "IN"},
                    headers=HEADERS,
                )
                
                if response.status_code != 200:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"TMDB returned status {response.status_code}"
                    )
                
                data = response.json()

                for item in data.get("results", []):
                    item["media_type"] = media_type

            try:
                await set_cache(cache_key, data, expire_seconds=3600)
            except Exception:
                pass

            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )


@router.get("/tv/{tv_id}", summary="Get TV Show Details")
async def get_tv_details(tv_id: int):
    cache_key = f"tv:details:v2:{tv_id}"
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
                    # 👇 Added watch/providers
                    "append_to_response": "credits,videos,watch/providers" 
                },
                headers=HEADERS,
            )
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            data["media_type"] = "tv"

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
    cache_key = f"person:details:v2:{person_id}"
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
            data["media_type"] = "person"

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
    cache_key = f"movies:details:v2:{movie_id}"

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
                    # 👇 Added watch/providers
                    "append_to_response": "credits,videos,watch/providers"
                },
                headers=HEADERS,
            )
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"TMDB API returned error: {response.status_code}"
                )
            
            data = response.json()
            data["media_type"] = "movie"

            await set_cache(cache_key, data, expire_seconds=43200)
            return data

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to connect to TMDB: {exc}"
            )