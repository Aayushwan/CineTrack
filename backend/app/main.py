from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.session import engine, Base
from app.core.redis import init_redis, close_redis  # 👈 1. Import Redis helpers
from app.routers.auth import router as auth_router
from app.routers.movies import router as movies_router
from app.routers.watchlist import router as watchlist_router
import app.models.review
from app.routers.reviews import router as reviews_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize DB tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # 👈 2. Connect to Redis on startup
    await init_redis()
    
    yield
    
    # 👈 3. Disconnect Redis on shutdown
    await close_redis()


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Asynchronous full-stack backend API for CineTrack.",
    version="0.1.0",
    docs_url="/docs" if settings.ENVIRONMENT == "local" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT == "local" else None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(movies_router)
app.include_router(watchlist_router)
app.include_router(reviews_router)


@app.get("/", tags=["Health Check"])
async def root_health_check():
    return {
        "status": "healthy",
        "project": settings.PROJECT_NAME,
        "environment": settings.ENVIRONMENT,
        "api_docs": "/docs" if settings.ENVIRONMENT == "local" else "disabled",
    }