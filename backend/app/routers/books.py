import uuid

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.book import Book
from app.models.user import User
from app.schemas.book import BookCreate, BookOut, BookSearchResult, BookUpdate

router = APIRouter(prefix="/books", tags=["books"])

GOOGLE_BOOKS_URL = "https://www.googleapis.com/books/v1/volumes"
OPEN_LIBRARY_URL = "https://openlibrary.org/search.json"

# Mirrors the fixed genre chip set in the Flutter app (widgets/genre_chip.dart)
GENRE_OPTIONS = [
    "Romance", "Fantasy", "Contemporary", "Thriller", "Mystery",
    "Sci-Fi", "Historical", "Horror", "Non-fiction", "Dark Academia",
]


def _compute_rating(cover: int | None, writing: int | None, plot: int | None, characters: int | None) -> int | None:
    values = [v for v in (cover, writing, plot, characters) if v is not None]
    if not values:
        return None
    return round(sum(values) / len(values))


def _guess_genre(categories: list[str]) -> str | None:
    joined = " ".join(categories).lower()
    for option in GENRE_OPTIONS:
        if option.lower() in joined:
            return option
    return None


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


def _search_google_books(q: str) -> list[BookSearchResult]:
    response = httpx.get(
        GOOGLE_BOOKS_URL,
        params={"q": q, "maxResults": 10, "printType": "books"},
        timeout=10.0,
    )
    response.raise_for_status()
    payload = response.json()

    results: list[BookSearchResult] = []
    for item in payload.get("items", []):
        info = item.get("volumeInfo", {})
        title = info.get("title")
        if not title:
            continue

        authors = info.get("authors") or []
        image_links = info.get("imageLinks") or {}
        cover_url = image_links.get("thumbnail") or image_links.get("smallThumbnail")
        if cover_url:
            cover_url = cover_url.replace("http://", "https://")

        results.append(
            BookSearchResult(
                title=title,
                author=", ".join(authors) if authors else "Unknown author",
                cover_url=cover_url,
                pages=info.get("pageCount"),
                published=info.get("publishedDate"),
                genre=_guess_genre(info.get("categories") or []),
            )
        )
    return results


def _search_open_library(q: str) -> list[BookSearchResult]:
    response = httpx.get(
        OPEN_LIBRARY_URL,
        params={
            "q": q,
            "limit": 10,
            "fields": "title,author_name,first_publish_year,number_of_pages_median,cover_i,subject",
        },
        timeout=10.0,
    )
    response.raise_for_status()
    payload = response.json()

    results: list[BookSearchResult] = []
    for doc in payload.get("docs", []):
        title = doc.get("title")
        if not title:
            continue

        authors = doc.get("author_name") or []
        cover_id = doc.get("cover_i")
        cover_url = f"https://covers.openlibrary.org/b/id/{cover_id}-L.jpg" if cover_id else None
        year = doc.get("first_publish_year")

        results.append(
            BookSearchResult(
                title=title,
                author=", ".join(authors) if authors else "Unknown author",
                cover_url=cover_url,
                pages=doc.get("number_of_pages_median"),
                published=str(year) if year else None,
                genre=_guess_genre(doc.get("subject") or []),
            )
        )
    return results


@router.get("/search", response_model=list[BookSearchResult])
def search_books(
    q: str = Query(min_length=2, max_length=200),
    current_user: User = Depends(get_current_user),
):
    # Google Books gives better cover art and metadata but has a low
    # unauthenticated quota; Open Library is unlimited and keyless, so it's
    # the reliability fallback when Google fails or comes back empty.
    try:
        results = _search_google_books(q)
    except httpx.HTTPError:
        results = []

    if not results:
        try:
            results = _search_open_library(q)
        except httpx.HTTPError:
            results = []

    return results


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
