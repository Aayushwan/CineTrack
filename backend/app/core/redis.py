import json
from typing import Optional, Any
import redis.asyncio as aioredis
from app.core.config import settings

redis_client: Optional[aioredis.Redis] = None


async def init_redis():
    global redis_client
    try:
        redis_client = aioredis.Redis(
            host=settings.REDIS_HOST,
            port=settings.REDIS_PORT,
            decode_responses=True,
        )
        await redis_client.ping()
        print("Connected to Redis successfully.")
    except Exception as e:
        print(f"Redis connection warning: {e}. Running without Redis cache.")
        redis_client = None


async def close_redis():
    global redis_client
    if redis_client:
        await redis_client.close()


async def get_cache(key: str) -> Optional[Any]:
    if not redis_client:
        return None
    try:
        data = await redis_client.get(key)
        return json.loads(data) if data else None
    except Exception:
        return None


async def set_cache(key: str, value: Any, expire_seconds: int = 3600):
    if not redis_client:
        return
    try:
        await redis_client.set(key, json.dumps(value), ex=expire_seconds)
    except Exception:
        pass