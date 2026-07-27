from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.session import engine, Base
from app.routers.auth import router as auth_router
from app.routers.movies import router as movies_router
from app.routers.watchlist import router as watchlist_router
import app.models.review
from app.routers.reviews import router as reviews_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create all database tables on startup if they don't exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Asynchronous full-stack backend API for CineTrack.",
    version="0.1.0",
    docs_url="/docs" if settings.ENVIRONMENT == "local" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT == "local" else None,
    lifespan=lifespan,
)

# Allow all origins for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
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