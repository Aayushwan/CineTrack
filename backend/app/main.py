from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.session import engine, Base
from app.core.redis import init_redis, close_redis

# Router Imports
from app.routers.auth import router as auth_router
from app.routers.media import router as media_router
from app.routers.watchlist import router as watchlist_router
from app.routers.reviews import router as reviews_router
from app.routers.history import router as history_router  # 👈 1. Import history router

# Model Imports (Ensures metadata is registered before create_all runs)
import app.models.review
import app.models.history  # 👈 2. Import history models


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize DB tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # Connect to Redis on startup
    await init_redis()
    
    yield
    
    # Disconnect Redis on shutdown
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

# Register API Routers
app.include_router(auth_router)
app.include_router(media_router)
app.include_router(watchlist_router)
app.include_router(reviews_router)
app.include_router(history_router)  # 👈 3. Include history router


@app.get("/", tags=["Health Check"])
async def root_health_check():
    return {
        "status": "healthy",
        "project": settings.PROJECT_NAME,
        "environment": settings.ENVIRONMENT,
        "api_docs": "/docs" if settings.ENVIRONMENT == "local" else "disabled",
    }