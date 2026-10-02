from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db.session import get_db
from app.models.custom_list import CustomList, CustomListItem
from app.schemas.custom_list import CustomListCreate, CustomListResponse, CustomListItemBase
from app.core.security import get_current_user 

router = APIRouter(prefix="/lists", tags=["Custom Lists"])

@router.get("/", response_model=list[CustomListResponse])
async def get_user_lists(user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(CustomList)
        .where(CustomList.user_id == user.id)
        .order_by(CustomList.created_at.desc())
    )
    lists = result.scalars().all()
    
    response = []
    for lst in lists:
        # Fetch the 5 most recent posters for the list preview
        items_res = await db.execute(
            select(CustomListItem.poster_path)
            .where(CustomListItem.list_id == lst.id)
            .order_by(CustomListItem.added_at.desc())
            .limit(5)
        )
        posters = [p for p in items_res.scalars().all() if p]
        
        # 👇 Dictionary unpacking fixes the Pylance type warnings
        response.append(CustomListResponse(**{
            "id": lst.id, 
            "name": lst.name, 
            "description": lst.description, 
            "posters": posters
        }))
    return response

@router.post("/", response_model=CustomListResponse)
async def create_list(lst: CustomListCreate, user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    # 👇 Dictionary unpacking fixes the Pylance type warnings
    new_list = CustomList(**{
        "user_id": user.id, 
        "name": lst.name, 
        "description": lst.description, 
        "is_private": lst.is_private
    })
    db.add(new_list)
    await db.commit()
    await db.refresh(new_list)
    
    return CustomListResponse(**{
        "id": new_list.id, 
        "name": new_list.name, 
        "description": new_list.description, 
        "posters": []
    })

@router.delete("/{list_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_list(list_id: int, user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(CustomList).where(CustomList.id == list_id, CustomList.user_id == user.id))
    lst = result.scalar_one_or_none()
    if not lst:
        raise HTTPException(status_code=404, detail="List not found")
    await db.delete(lst)
    await db.commit()

@router.post("/{list_id}/items", status_code=status.HTTP_201_CREATED)
async def add_item_to_list(list_id: int, item: CustomListItemBase, user = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    # Verify ownership
    result = await db.execute(select(CustomList).where(CustomList.id == list_id, CustomList.user_id == user.id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="List not found")
    
    # Check if already added
    exist = await db.execute(select(CustomListItem).where(CustomListItem.list_id == list_id, CustomListItem.movie_id == item.movie_id))
    if exist.scalar_one_or_none():
        return {"msg": "Already in list"}

    # 👇 Dictionary unpacking
    new_item = CustomListItem(**{
        "list_id": list_id, 
        "movie_id": item.movie_id, 
        "poster_path": item.poster_path
    })
    db.add(new_item)
    await db.commit()
    return {"msg": "Added successfully"}