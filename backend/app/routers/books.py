import math
import uuid

import httpx
import sqlalchemy as sa
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.book import Book
from app.models.user import User
from app.schemas.book import BookCreate, BookOut, BookSearchResult, BookUpdate
from app.schemas.pagination import Page, PageParams

router = APIRouter(prefix="/books", tags=["books"])

GOOGLE_BOOKS_URL = "https://www.googleapis.com/books/v1/volumes"
OPEN_LIBRARY_URL = "https://openlibrary.org/search.json"

# Mirrors the fixed genre chip set in the Flutter app (widgets/genre_chip.dart)
GENRE_OPTIONS = [
    "Romance", "Fantasy", "Contemporary", "Thriller", "Mystery",
    "Sci-Fi", "Historical", "Horror", "Non-fiction", "Dark Academia",
]


def _compute_rating(cover: int | None, writing: int | None, plot: int | None, characters: int | None) -> float | None:
    values = [v for v in (cover, writing, plot, characters) if v is not None]
    if not values:
        return None
    # Round to the nearest half star, half-up (not banker's rounding — round()
    # would otherwise round an exact .5-star tie down to the even star, e.g. 2.25 -> 2 instead of 2.5).
    avg = sum(values) / len(values)
    return math.floor(avg * 2 + 0.5) / 2


SORT_OPTIONS = {
    "title": lambda: sa.func.lower(Book.title).asc(),
    "author": lambda: sa.func.lower(Book.author).asc(),
    "pages": lambda: Book.pages.desc().nulls_last(),
    "times_read": lambda: Book.times_read.desc(),
    "end_date": lambda: Book.end_date.desc().nulls_last(),
}


@router.get("", response_model=Page[BookOut])
def list_books(
    filter: str = Query(default="all", pattern="^(all|toBuy|reading|read)$"),
    q: str | None = Query(default=None, max_length=200),
    sort: str = Query(default="title", pattern="^(title|author|pages|times_read|end_date)$"),
    page: PageParams = Depends(),
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

    if q:
        needle = f"%{q.strip()}%"
        query = query.filter(sa.or_(Book.title.ilike(needle), Book.author.ilike(needle), Book.series.ilike(needle)))

    total = query.count()
    # Tie-break everything by title so equal/null sort keys still land in a stable order.
    items = (
        query.order_by(SORT_OPTIONS[sort](), sa.func.lower(Book.title).asc())
        .limit(page.limit)
        .offset(page.offset)
        .all()
    )
    return Page(items=items, total=total, limit=page.limit, offset=page.offset)


def _guess_genre(categories: list[str]) -> str | None:
    joined = " ".join(categories).lower()
    for option in GENRE_OPTIONS:
        if option.lower() in joined:
            return option
    return None


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

    # A book added as already-read has clearly been read at least once.
    times_read = 1 if data["read"] else 0

    book = Book(user_id=current_user.id, rating=rating, times_read=times_read, **data)
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
    was_read = book.read

    for field, value in updates.items():
        setattr(book, field, value)

    # Marking a book read (and not explicitly setting times_read in the same
    # request) counts as finishing it at least once more.
    if book.read and not was_read and "times_read" not in updates:
        book.times_read += 1

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
