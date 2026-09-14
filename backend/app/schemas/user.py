import uuid

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = Field(min_length=1, max_length=120)
    reading_goal: int = Field(default=40, ge=1, le=999)
    genres: list[str] = Field(default_factory=list)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    reading_goal: int | None = Field(default=None, ge=1, le=999)
    genres: list[str] | None = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    name: str
    reading_goal: int
    genres: list[str]


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
