import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.bingo import BingoCard, BingoSquare
from app.models.user import User
from app.schemas.bingo import BingoCardOut, BingoSquareUpdate

router = APIRouter(prefix="/bingo", tags=["bingo"])

DEFAULT_LABELS = [
    "Read a debut author", "Book under 250 pages", "Author you've never read", "One-word title", "Read outdoors",
    "A retelling", "Book club pick", "Enemies to lovers", "A buddy read", "Published this year",
    "Recommended by a friend", "A trope you avoid", "FREE SPACE", "Finish in one sitting", "Book over 500 pages",
    "Audiobook", "Reread a favourite", "Cover you love", "Backlist title", "Translated work",
    "Series finale", "Cozy mystery", "Non-fiction pick", "Banned book", "5-star surprise",
]


def _get_or_create_current_card(user_id: uuid.UUID, db: Session) -> BingoCard:
    year = date.today().year
    card = db.query(BingoCard).filter(BingoCard.user_id == user_id, BingoCard.year == year).first()
    if card is not None:
        return card

    card = BingoCard(user_id=user_id, year=year)
    db.add(card)
    db.flush()

    for position, label in enumerate(DEFAULT_LABELS):
        is_free = position == 12
        db.add(BingoSquare(card_id=card.id, position=position, label=label, completed=is_free, locked=is_free))

    db.commit()
    db.refresh(card)
    return card


def _available_years(user_id: uuid.UUID, db: Session) -> list[int]:
    rows = db.query(BingoCard.year).filter(BingoCard.user_id == user_id).distinct().all()
    years = {y for (y,) in rows}
    years.add(date.today().year)
    return sorted(years, reverse=True)


def _serialize(card: BingoCard, user_id: uuid.UUID, db: Session) -> BingoCardOut:
    out = BingoCardOut.model_validate(card)
    out.available_years = _available_years(user_id, db)
    return out


@router.get("", response_model=BingoCardOut)
def get_bingo_card(
    year: int | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_year = date.today().year
    selected_year = year or current_year

    if selected_year == current_year:
        card = _get_or_create_current_card(current_user.id, db)
    else:
        card = db.query(BingoCard).filter(BingoCard.user_id == current_user.id, BingoCard.year == selected_year).first()
        if card is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, f"No bingo card for {selected_year}")

    return _serialize(card, current_user.id, db)


@router.patch("/squares/{square_id}", response_model=BingoCardOut)
def update_square(
    square_id: uuid.UUID,
    payload: BingoSquareUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    square = db.get(BingoSquare, square_id)
    if square is None or square.card.user_id != current_user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bingo square not found")
    if square.locked:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This square can't be edited")
    if square.card.year != date.today().year:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Only this year's card can be edited")

    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(square, field, value)

    db.commit()
    return _serialize(_get_or_create_current_card(current_user.id, db), current_user.id, db)


@router.post("/reset", response_model=BingoCardOut)
def reset_card(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    card = _get_or_create_current_card(current_user.id, db)
    for square in card.squares:
        if not square.locked:
            square.completed = False

    db.commit()
    db.refresh(card)
    return _serialize(card, current_user.id, db)
