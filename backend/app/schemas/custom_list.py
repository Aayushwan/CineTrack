# backend/app/schemas/custom_list.py
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

# ─── Requests ───

class ListItemCreate(BaseModel):
    media_id: str
    media_type: str
    title: str
    poster_path: Optional[str] = None
    movie_id: Optional[int] = None # Backward compatibility

class ListRenameRequest(BaseModel):
    name: str

class CustomListCreate(BaseModel):
    name: str
    description: Optional[str] = None
    is_private: bool = True

# ─── Responses ───

class ListItemResponse(BaseModel):
    id: str
    media_id: str
    media_type: str
    title: str
    poster_path: Optional[str] = None

    class Config:
        from_attributes = True

class CustomListResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    items: List[ListItemResponse] = [] # 👈 Now returns a list of full items instead of just poster strings
    
    class Config:
        from_attributes = True