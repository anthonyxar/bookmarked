import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Path, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.book import Book
from app.models.bracket import BracketPick, MonthlyFavorite
from app.models.user import User
from app.schemas.bracket import (
    BracketBookOut,
    BracketFavoriteOut,
    BracketMatchOut,
    BracketOut,
    BracketWinnerSet,
    MonthlyFavoriteSet,
)

router = APIRouter(prefix="/bracket", tags=["bracket"])

# Wildcard round pairs the 8 non-bye months (in month order); the 4
# highest-rated months skip straight to the quarterfinals.
_WC_PAIR_COUNT = 4
_BYE_COUNT = 4


def _book_brief(book: Book, month: int | None = None) -> BracketBookOut:
    return BracketBookOut(
        id=book.id,
        title=book.title,
        author=book.author,
        cover_color=book.cover_color,
        cover_url=book.cover_url,
        rating=book.rating,
        month=month,
    )


def _compute_bracket(year: int, user_id: uuid.UUID, db: Session) -> BracketOut:
    favorites = db.query(MonthlyFavorite).filter(MonthlyFavorite.user_id == user_id, MonthlyFavorite.year == year).all()
    fav_by_month = {f.month: f for f in favorites}

    entries: dict[int, tuple[int, Book]] = {}
    favorites_out = []
    for month in range(1, 13):
        fav = fav_by_month.get(month)
        book = db.get(Book, fav.book_id) if fav else None
        favorites_out.append(BracketFavoriteOut(month=month, book=_book_brief(book, month) if book else None))
        if book is not None:
            entries[month] = (month, book)

    if len(entries) < 12:
        return BracketOut(year=year, months_set=len(entries), favorites=favorites_out, matches=None, champion=None)

    picks = {
        p.match_id: p.book_id
        for p in db.query(BracketPick).filter(BracketPick.user_id == user_id, BracketPick.year == year).all()
    }

    ranked = sorted(entries.values(), key=lambda e: (-(e[1].rating or 0), e[0]))
    byes = sorted(ranked[:_BYE_COUNT], key=lambda e: e[0])
    wc_entrants = sorted(ranked[_BYE_COUNT:], key=lambda e: e[0])
    wc_pairs = [tuple(wc_entrants[i * 2 : i * 2 + 2]) for i in range(_WC_PAIR_COUNT)]

    matches: list[BracketMatchOut] = []

    def resolve(match_id: str, round_name: str, a: tuple[int, Book] | None, b: tuple[int, Book] | None) -> tuple[int, Book] | None:
        winner_id = picks.get(match_id)
        matches.append(
            BracketMatchOut(
                id=match_id,
                round=round_name,
                book_a=_book_brief(a[1], a[0]) if a else None,
                book_b=_book_brief(b[1], b[0]) if b else None,
                winner_id=winner_id,
            )
        )
        if winner_id is None:
            return None
        for entry in (a, b):
            if entry is not None and entry[1].id == winner_id:
                return entry
        return None

    wc_winners = [resolve(f"wc{i + 1}", "wildcard", a, b) for i, (a, b) in enumerate(wc_pairs)]
    qf_winners = [resolve(f"qf{i + 1}", "quarterfinal", byes[i], wc_winners[i]) for i in range(4)]
    sf_winners = [
        resolve("sf1", "semifinal", qf_winners[0], qf_winners[1]),
        resolve("sf2", "semifinal", qf_winners[2], qf_winners[3]),
    ]
    final_winner = resolve("final", "final", sf_winners[0], sf_winners[1])

    champion = _book_brief(final_winner[1], final_winner[0]) if final_winner else None
    return BracketOut(year=year, months_set=12, favorites=favorites_out, matches=matches, champion=champion)


@router.get("/{year}", response_model=BracketOut)
def get_bracket(year: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _compute_bracket(year, current_user.id, db)


@router.put("/{year}/favorites/{month}", response_model=BracketOut)
def set_monthly_favorite(
    year: int,
    month: int = Path(ge=1, le=12),
    payload: MonthlyFavoriteSet = ...,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    book = db.get(Book, payload.book_id)
    if book is None or book.user_id != current_user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Book not found")
    if not book.read:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Only a book you've read can be a monthly favourite")

    existing = (
        db.query(MonthlyFavorite)
        .filter(MonthlyFavorite.user_id == current_user.id, MonthlyFavorite.year == year, MonthlyFavorite.month == month)
        .first()
    )
    if existing:
        existing.book_id = book.id
    else:
        db.add(MonthlyFavorite(user_id=current_user.id, year=year, month=month, book_id=book.id))

    db.commit()
    return _compute_bracket(year, current_user.id, db)


@router.delete("/{year}/favorites/{month}", response_model=BracketOut)
def clear_monthly_favorite(
    year: int,
    month: int = Path(ge=1, le=12),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.query(MonthlyFavorite).filter(
        MonthlyFavorite.user_id == current_user.id, MonthlyFavorite.year == year, MonthlyFavorite.month == month
    ).delete()
    db.commit()
    return _compute_bracket(year, current_user.id, db)


@router.post("/{year}/matches/{match_id}", response_model=BracketOut)
def set_match_winner(
    year: int,
    match_id: str,
    payload: BracketWinnerSet,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bracket = _compute_bracket(year, current_user.id, db)
    match = next((m for m in (bracket.matches or []) if m.id == match_id), None)
    if match is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "That match isn't available yet")

    valid_ids = {b.id for b in (match.book_a, match.book_b) if b is not None}
    if payload.book_id not in valid_ids:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "That book isn't one of this match's two picks")

    existing = (
        db.query(BracketPick)
        .filter(BracketPick.user_id == current_user.id, BracketPick.year == year, BracketPick.match_id == match_id)
        .first()
    )
    if existing:
        existing.book_id = payload.book_id
    else:
        db.add(BracketPick(user_id=current_user.id, year=year, match_id=match_id, book_id=payload.book_id))

    db.commit()
    return _compute_bracket(year, current_user.id, db)
