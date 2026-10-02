from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class CustomListItemBase(BaseModel):
    movie_id: int
    poster_path: Optional[str] = None

class CustomListCreate(BaseModel):
    name: str
    description: Optional[str] = None
    is_private: bool = True

class CustomListResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    posters: List[str] = []
    
    class Config:
        from_attributes = True