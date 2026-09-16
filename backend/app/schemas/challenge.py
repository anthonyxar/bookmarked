from pydantic import BaseModel


class ChallengeOut(BaseModel):
    id: str
    title: str
    description: str
    progress: int
    goal: int
    auto_tracked: bool = True
    letters: list[bool] | None = None


class ChallengesOut(BaseModel):
    year: int
    challenges: list[ChallengeOut]
