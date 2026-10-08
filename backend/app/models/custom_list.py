# backend/app/models/custom_list.py
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.session import Base

class CustomList(Base):
    __tablename__ = "custom_lists"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    is_private = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # 👇 Updated to point to the new ListItem class
    items = relationship("ListItem", back_populates="custom_list", cascade="all, delete-orphan")


class ListItem(Base):
    # 👇 Updated to match your Supabase table name
    __tablename__ = "list_items"

    id = Column(Integer, primary_key=True, index=True)
    list_id = Column(Integer, ForeignKey("custom_lists.id", ondelete="CASCADE"), nullable=False)
    
    # 👇 Replaced movie_id with media_id, media_type, and title
    media_id = Column(String, nullable=False)
    media_type = Column(String, nullable=False)
    title = Column(String, nullable=False)
    
    poster_path = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)
    added_at = Column(DateTime(timezone=True), server_default=func.now())

    # 👇 Relationship pointing back to the parent list
    custom_list = relationship("CustomList", back_populates="items")