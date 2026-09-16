import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.club import ClubMembershipStatus, ClubRole


class ClubCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = None


class ClubUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = None


class ClubMemberOut(BaseModel):
    user_id: uuid.UUID
    name: str
    email: str
    avatar_url: str | None = None
    role: ClubRole
    status: ClubMembershipStatus
    current_chapter: int | None = None
    finished: bool | None = None


class ClubBookOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    author: str
    total_chapters: int | None
    cover_color: str
    cover_url: str | None
    is_current: bool
    start_date: date | None
    end_date: date | None
    picked_at: datetime


class ClubOut(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    owner_id: uuid.UUID
    my_role: ClubRole
    created_at: datetime
    members: list[ClubMemberOut]
    current_book: ClubBookOut | None


class ClubInviteCreate(BaseModel):
    email: EmailStr


class ClubInviteOut(BaseModel):
    club_id: uuid.UUID
    club_name: str
    invited_by_name: str
    invited_at: datetime


class ClubInviteRespond(BaseModel):
    accept: bool


class ClubMemberUpdate(BaseModel):
    role: ClubRole | None = None
    remove: bool = False


class ClubOwnershipTransfer(BaseModel):
    new_owner_id: uuid.UUID


class ClubBookCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    author: str = Field(min_length=1, max_length=255)
    total_chapters: int | None = Field(default=None, ge=1)
    cover_color: str = "#3F5D4E"
    cover_url: str | None = None
    start_date: date | None = None
    end_date: date | None = None


class ClubBookDatesUpdate(BaseModel):
    start_date: date | None = None
    end_date: date | None = None


class ClubProgressUpdate(BaseModel):
    current_chapter: int | None = Field(default=None, ge=0)
    finished: bool | None = None


class ClubNoteCreate(BaseModel):
    chapter: int = Field(ge=0)
    body: str = Field(min_length=1)


class ClubNoteOut(BaseModel):
    id: uuid.UUID
    chapter: int
    body: str
    user_id: uuid.UUID
    author_name: str
    created_at: datetime
    updated_at: datetime


class ClubReviewEntryOut(BaseModel):
    user_id: uuid.UUID
    name: str
    finished: bool
    locked: bool
    spoiler_warning: str | None = None
    # Only populated on the viewer's own entry, pointing at their personal
    # Book row so the app can link straight to it instead of duplicating it.
    book_id: uuid.UUID | None = None

    rating: float | None = None
    rating_cover: int | None = None
    rating_writing: int | None = None
    rating_plot: int | None = None
    rating_characters: int | None = None
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


class ClubBingoTemplateCreate(BaseModel):
    labels: list[str] = Field(min_length=25, max_length=25)


class ClubMemberBingoSquareOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    position: int
    label: str
    completed: bool
    locked: bool


class ClubBingoLeaderboardEntryOut(BaseModel):
    user_id: uuid.UUID
    name: str
    completed_count: int
    total_count: int
    won_at: datetime | None


class ClubBingoOut(BaseModel):
    squares: list[ClubMemberBingoSquareOut]
    leaderboard: list[ClubBingoLeaderboardEntryOut]


class ClubBingoSquareUpdate(BaseModel):
    completed: bool
