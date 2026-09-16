import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.book import BookFormat


class BookCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    author: str = Field(min_length=1, max_length=255)
    series: str | None = None
    book_no: int | None = None
    genre: str | None = None
    cover_color: str = "#3F5D4E"
    cover_url: str | None = None
    published: str | None = None
    pages: int | None = None
    format: BookFormat = BookFormat.physical

    purchased: bool = False
    read: bool = False
    start_date: date | None = None
    end_date: date | None = None

    rating_cover: int | None = Field(default=None, ge=0, le=5)
    rating_writing: int | None = Field(default=None, ge=0, le=5)
    rating_plot: int | None = Field(default=None, ge=0, le=5)
    rating_characters: int | None = Field(default=None, ge=0, le=5)
    enjoyed: bool | None = None
    read_again: bool | None = None
    liked_most: str | None = None
    liked_least: str | None = None
    feel: str | None = None
    trope: str | None = None
    final_review: str | None = None
    favorite_characters: list[str] = Field(default_factory=list)
    notable_scenes: list[str] = Field(default_factory=list)
    quotes: list[str] = Field(default_factory=list)


class BookUpdate(BaseModel):
    title: str | None = None
    author: str | None = None
    series: str | None = None
    book_no: int | None = None
    genre: str | None = None
    cover_color: str | None = None
    cover_url: str | None = None
    published: str | None = None
    pages: int | None = None
    format: BookFormat | None = None

    purchased: bool | None = None
    read: bool | None = None
    times_read: int | None = None
    start_date: date | None = None
    end_date: date | None = None

    rating_cover: int | None = Field(default=None, ge=0, le=5)
    rating_writing: int | None = Field(default=None, ge=0, le=5)
    rating_plot: int | None = Field(default=None, ge=0, le=5)
    rating_characters: int | None = Field(default=None, ge=0, le=5)
    enjoyed: bool | None = None
    read_again: bool | None = None
    liked_most: str | None = None
    liked_least: str | None = None
    feel: str | None = None
    trope: str | None = None
    final_review: str | None = None
    favorite_characters: list[str] | None = None
    notable_scenes: list[str] | None = None
    quotes: list[str] | None = None


class BookOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    author: str
    series: str | None
    book_no: int | None
    genre: str | None
    cover_color: str
    cover_url: str | None
    published: str | None
    pages: int | None
    format: BookFormat

    purchased: bool
    read: bool
    times_read: int
    start_date: date | None
    end_date: date | None

    rating: float | None
    rating_cover: int | None
    rating_writing: int | None
    rating_plot: int | None
    rating_characters: int | None
    enjoyed: bool | None
    read_again: bool | None
    liked_most: str | None
    liked_least: str | None
    feel: str | None
    trope: str | None
    final_review: str | None
    favorite_characters: list[str]
    notable_scenes: list[str]
    quotes: list[str]

    created_at: datetime
    updated_at: datetime


class BookSearchResult(BaseModel):
    title: str
    author: str
    cover_url: str | None = None
    pages: int | None = None
    published: str | None = None
    genre: str | None = None
