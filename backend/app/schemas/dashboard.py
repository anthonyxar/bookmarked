from pydantic import BaseModel


class GenreCount(BaseModel):
    genre: str
    count: int


class RatingCount(BaseModel):
    rating: float
    count: int


class MonthCount(BaseModel):
    month: int
    count: int


class DashboardOut(BaseModel):
    year: int
    available_years: list[int]
    total_read: int
    avg_rating: float
    pages_read: int
    by_genre: list[GenreCount]
    by_rating: list[RatingCount]
    by_month: list[MonthCount]
