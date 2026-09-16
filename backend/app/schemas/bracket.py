import uuid

from pydantic import BaseModel, Field


class MonthlyFavoriteSet(BaseModel):
    book_id: uuid.UUID


class BracketWinnerSet(BaseModel):
    book_id: uuid.UUID


class BracketBookOut(BaseModel):
    id: uuid.UUID
    title: str
    author: str
    cover_color: str
    cover_url: str | None
    rating: float | None
    month: int | None = None


class BracketFavoriteOut(BaseModel):
    month: int
    book: BracketBookOut | None


class BracketMatchOut(BaseModel):
    id: str
    round: str
    book_a: BracketBookOut | None
    book_b: BracketBookOut | None
    winner_id: uuid.UUID | None


class BracketOut(BaseModel):
    year: int
    months_set: int = Field(description="How many of the 12 months have a favourite picked")
    favorites: list[BracketFavoriteOut]
    matches: list[BracketMatchOut] | None
    champion: BracketBookOut | None
