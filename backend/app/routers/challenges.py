import string
from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import extract
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.book import Book
from app.models.user import User
from app.routers.books import GENRE_OPTIONS
from app.schemas.challenge import ChallengeOut, ChallengesOut

router = APIRouter(prefix="/challenges", tags=["challenges"])


def _az_progress(titles: list[str]) -> list[bool]:
    leads = set()
    for title in titles:
        stripped = title.strip()
        if stripped and stripped[0].upper() in string.ascii_uppercase:
            leads.add(stripped[0].upper())
    return [letter in leads for letter in string.ascii_uppercase]


@router.get("", response_model=ChallengesOut)
def get_challenges(
    year: int | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    selected_year = year or date.today().year

    read_books = (
        db.query(Book)
        .filter(
            Book.user_id == current_user.id,
            Book.read.is_(True),
            extract("year", Book.end_date) == selected_year,
        )
        .all()
    )

    letters = _az_progress([b.title for b in read_books])
    genres_hit = {b.genre for b in read_books if b.genre in GENRE_OPTIONS}
    chunky_count = sum(1 for b in read_books if (b.pages or 0) > 500)
    five_star_count = sum(1 for b in read_books if b.rating == 5.0)

    challenges = [
        ChallengeOut(
            id="az_titles",
            title="A–Z Titles",
            description="Read a book whose title starts with every letter of the alphabet.",
            progress=sum(letters),
            goal=26,
            letters=letters,
        ),
        ChallengeOut(
            id="genre_explorer",
            title="Genre Explorer",
            description="Read at least one book in every genre.",
            progress=len(genres_hit),
            goal=len(GENRE_OPTIONS),
        ),
        ChallengeOut(
            id="chunky_reads",
            title="Chunky Reads",
            description="Finish five books over 500 pages.",
            progress=min(chunky_count, 5),
            goal=5,
        ),
        ChallengeOut(
            id="five_star_shelf",
            title="Five-Star Shelf",
            description="Rate ten books the full five stars.",
            progress=min(five_star_count, 10),
            goal=10,
        ),
    ]

    return ChallengesOut(year=selected_year, challenges=challenges)
