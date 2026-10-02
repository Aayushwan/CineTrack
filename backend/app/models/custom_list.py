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

    items = relationship("CustomListItem", back_populates="custom_list", cascade="all, delete-orphan")

class CustomListItem(Base):
    __tablename__ = "custom_list_items"

    id = Column(Integer, primary_key=True, index=True)
    list_id = Column(Integer, ForeignKey("custom_lists.id", ondelete="CASCADE"))
    movie_id = Column(Integer, nullable=False)
    poster_path = Column(String, nullable=True)
    added_at = Column(DateTime(timezone=True), server_default=func.now())

    custom_list = relationship("CustomList", back_populates="items")