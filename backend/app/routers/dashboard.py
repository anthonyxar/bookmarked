from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.book import Book
from app.models.user import User
from app.schemas.dashboard import DashboardOut, GenreCount, MonthCount, RatingCount

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("", response_model=DashboardOut)
def get_dashboard(
    year: int | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_year = date.today().year
    selected_year = year or current_year

    read_books = db.query(Book).filter(
        Book.user_id == current_user.id,
        Book.read.is_(True),
        extract("year", Book.end_date) == selected_year,
    )

    total_read = read_books.count()
    avg_rating = db.query(func.avg(Book.rating)).filter(
        Book.user_id == current_user.id,
        Book.read.is_(True),
        Book.rating.isnot(None),
        extract("year", Book.end_date) == selected_year,
    ).scalar() or 0
    pages_read = db.query(func.coalesce(func.sum(Book.pages), 0)).filter(
        Book.user_id == current_user.id,
        Book.read.is_(True),
        extract("year", Book.end_date) == selected_year,
    ).scalar()

    genre_rows = (
        db.query(Book.genre, func.count(Book.id))
        .filter(
            Book.user_id == current_user.id,
            Book.read.is_(True),
            Book.genre.isnot(None),
            extract("year", Book.end_date) == selected_year,
        )
        .group_by(Book.genre)
        .order_by(func.count(Book.id).desc())
        .all()
    )

    rating_rows = (
        db.query(Book.rating, func.count(Book.id))
        .filter(
            Book.user_id == current_user.id,
            Book.read.is_(True),
            Book.rating.isnot(None),
            extract("year", Book.end_date) == selected_year,
        )
        .group_by(Book.rating)
        .order_by(Book.rating.desc())
        .all()
    )

    month_rows = (
        db.query(extract("month", Book.end_date), func.count(Book.id))
        .filter(
            Book.user_id == current_user.id,
            Book.read.is_(True),
            Book.end_date.isnot(None),
            extract("year", Book.end_date) == selected_year,
        )
        .group_by(extract("month", Book.end_date))
        .all()
    )
    month_counts = {int(m): c for m, c in month_rows}

    year_rows = (
        db.query(extract("year", Book.end_date))
        .filter(Book.user_id == current_user.id, Book.read.is_(True), Book.end_date.isnot(None))
        .distinct()
        .all()
    )
    available_years = sorted({int(y) for (y,) in year_rows} | {current_year}, reverse=True)

    return DashboardOut(
        year=selected_year,
        available_years=available_years,
        total_read=total_read,
        avg_rating=round(float(avg_rating), 1),
        pages_read=pages_read,
        by_genre=[GenreCount(genre=g, count=c) for g, c in genre_rows],
        by_rating=[RatingCount(rating=r, count=c) for r, c in rating_rows],
        by_month=[MonthCount(month=m, count=month_counts.get(m, 0)) for m in range(1, 13)],
    )
