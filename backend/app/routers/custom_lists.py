# backend/app/routers/custom_lists.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import delete, update
from app.db.session import get_db
from app.models.custom_list import CustomList, ListItem 

# 👇 Now cleanly importing all schemas from your updated schemas file!
from app.schemas.custom_list import CustomListCreate, ListRenameRequest, ListItemCreate
from app.core.security import get_current_user 

router = APIRouter(prefix="/lists", tags=["Custom Lists"])

# ─── Routes ───

@router.get("/")
async def get_user_lists(user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(CustomList)
        .where(CustomList.user_id == user.id)
        .order_by(CustomList.created_at.desc())
    )
    lists = result.scalars().all()
    
    response = []
    for lst in lists:
        items_res = await db.execute(
            select(ListItem)
            .where(ListItem.list_id == lst.id)
            .order_by(ListItem.added_at.desc())
        )
        items = items_res.scalars().all()
        
        formatted_items = [{
            "id": item.media_id, 
            "media_id": item.media_id,
            "media_type": item.media_type,
            "title": item.title,
            "poster_path": item.poster_path
        } for item in items]
        
        response.append({
            "id": lst.id, 
            "name": lst.name, 
            "description": lst.description, 
            "items": formatted_items
        })
    return response


@router.post("/")
async def create_list(lst: CustomListCreate, user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    new_list = CustomList(**{
        "user_id": user.id, 
        "name": lst.name, 
        "description": lst.description, 
        "is_private": lst.is_private
    })
    db.add(new_list)
    await db.commit()
    await db.refresh(new_list)
    
    return {
        "id": new_list.id, 
        "name": new_list.name, 
        "description": new_list.description, 
        "items": []
    }


@router.put("/{list_id}")
async def rename_custom_list(list_id: int, payload: ListRenameRequest, user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CustomList).where(CustomList.id == list_id, CustomList.user_id == user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="List not found")

    await db.execute(
        update(CustomList)
        .where(CustomList.id == list_id)
        .values(name=payload.name)
    )
    await db.commit()
    return {"message": "List renamed successfully", "new_name": payload.name}


@router.delete("/{list_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_list(list_id: int, user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CustomList).where(CustomList.id == list_id, CustomList.user_id == user.id))
    lst = result.scalar_one_or_none()
    if not lst:
        raise HTTPException(status_code=404, detail="List not found")
    await db.delete(lst)
    await db.commit()


@router.post("/{list_id}/items", status_code=status.HTTP_201_CREATED)
async def add_item_to_list(list_id: int, payload: ListItemCreate, user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CustomList).where(CustomList.id == list_id, CustomList.user_id == user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="List not found")
    
    media_id_val = str(payload.media_id) if payload.media_id else str(payload.movie_id)
    exist = await db.execute(select(ListItem).where(ListItem.list_id == list_id, ListItem.media_id == media_id_val))
    if exist.scalar_one_or_none():
        return {"msg": "Already in list"}

    new_item = ListItem(**{
        "list_id": list_id, 
        "media_id": media_id_val, 
        "media_type": payload.media_type,
        "title": payload.title,
        "poster_path": payload.poster_path
    })
    db.add(new_item)
    await db.commit()
    return {"msg": "Added successfully"}


@router.delete("/{list_id}/items/{media_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_item_from_list(list_id: int, media_id: str, user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CustomList).where(CustomList.id == list_id, CustomList.user_id == user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="List not found")

    delete_stmt = delete(ListItem).where(
        ListItem.list_id == list_id,
        ListItem.media_id == media_id
    )
    await db.execute(delete_stmt)
    await db.commit()
    return None