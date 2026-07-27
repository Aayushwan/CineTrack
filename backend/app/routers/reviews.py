from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db.session import get_db
from app.models.review import Review
from app.models.user import User
from app.schemas.review import ReviewCreate, ReviewResponse
from app.core.security import get_current_user

router = APIRouter(prefix="/reviews", tags=["Reviews"])

@router.post("/", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
async def create_review(
    review_in: ReviewCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    new_review = Review(
        user_id=current_user.id,
        movie_id=review_in.movie_id,
        rating=review_in.rating,
        comment=review_in.comment
    )
    db.add(new_review)
    await db.commit()
    await db.refresh(new_review)

    return ReviewResponse(
        id=int(new_review.id),
        user_id=int(new_review.user_id),
        username=str(current_user.username),
        movie_id=int(new_review.movie_id),
        rating=float(new_review.rating),
        comment=new_review.comment,
        created_at=new_review.created_at
    )

@router.get("/movie/{movie_id}", response_model=list[ReviewResponse])
async def get_movie_reviews(
    movie_id: int,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Review, User.username)
        .join(User, Review.user_id == User.id)
        .where(Review.movie_id == movie_id)
        .order_by(Review.created_at.desc())
    )
    reviews_data = result.all()

    return [
        ReviewResponse(
            id=int(rev.id),
            user_id=int(rev.user_id),
            username=str(username),
            movie_id=int(rev.movie_id),
            rating=float(rev.rating),
            comment=rev.comment,
            created_at=rev.created_at
        )
        for rev, username in reviews_data
    ]