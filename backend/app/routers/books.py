import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.book import Book
from app.models.user import User
from app.schemas.book import BookCreate, BookOut, BookUpdate

router = APIRouter(prefix="/books", tags=["books"])


def _compute_rating(cover: int | None, writing: int | None, plot: int | None, characters: int | None) -> int | None:
    values = [v for v in (cover, writing, plot, characters) if v is not None]
    if not values:
        return None
    return round(sum(values) / len(values))


@router.get("", response_model=list[BookOut])
def list_books(
    filter: str = Query(default="all", pattern="^(all|toBuy|reading|read)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Book).filter(Book.user_id == current_user.id)
    if filter == "toBuy":
        query = query.filter(Book.purchased.is_(False))
    elif filter == "reading":
        query = query.filter(Book.purchased.is_(True), Book.read.is_(False))
    elif filter == "read":
        query = query.filter(Book.read.is_(True))

    return query.order_by(Book.created_at.desc()).all()


@router.post("", response_model=BookOut, status_code=status.HTTP_201_CREATED)
def create_book(payload: BookCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    data = payload.model_dump()
    if data["read"] and data.get("rating_cover") is not None:
        rating = _compute_rating(data["rating_cover"], data["rating_writing"], data["rating_plot"], data["rating_characters"])
    else:
        rating = None

    book = Book(user_id=current_user.id, rating=rating, **data)
    db.add(book)
    db.commit()
    db.refresh(book)
    return book


def _get_owned_book(book_id: uuid.UUID, current_user: User, db: Session) -> Book:
    book = db.get(Book, book_id)
    if book is None or book.user_id != current_user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Book not found")
    return book


@router.get("/{book_id}", response_model=BookOut)
def get_book(book_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _get_owned_book(book_id, current_user, db)


@router.patch("/{book_id}", response_model=BookOut)
def update_book(
    book_id: uuid.UUID,
    payload: BookUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    book = _get_owned_book(book_id, current_user, db)
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(book, field, value)

    if book.read:
        book.rating = _compute_rating(book.rating_cover, book.rating_writing, book.rating_plot, book.rating_characters)
    else:
        book.rating = None

    db.commit()
    db.refresh(book)
    return book


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book(book_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    book = _get_owned_book(book_id, current_user, db)
    db.delete(book)
    db.commit()
