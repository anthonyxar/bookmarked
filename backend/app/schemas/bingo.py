import uuid

from pydantic import BaseModel, ConfigDict, Field


class BingoSquareOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    position: int
    label: str
    completed: bool
    locked: bool


class BingoCardOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    year: int
    squares: list[BingoSquareOut]


class BingoSquareUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=1, max_length=120)
    completed: bool | None = None
