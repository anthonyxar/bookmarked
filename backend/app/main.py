import logging
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import auth, bingo, books, bracket, challenges, clubs, dashboard, users

logger = logging.getLogger("bookmarked")

app = FastAPI(title="Bookmarked API", version="0.1.0")

if settings.jwt_secret == "change-me-in-production":
    logger.warning(
        "JWT_SECRET is set to its insecure default. Set a real secret via the "
        "JWT_SECRET environment variable before deploying anywhere reachable "
        "by untrusted clients."
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    # Auth is a bearer token in the Authorization header, not a cookie, so
    # the client never needs "credentials" (cookies/TLS certs) in the CORS
    # sense. Wildcard origins + allow_credentials=True is also invalid per
    # spec and browsers reject it outright.
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

Path("uploads").mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(books.router)
app.include_router(bingo.router)
app.include_router(clubs.router)
app.include_router(dashboard.router)
app.include_router(challenges.router)
app.include_router(bracket.router)


@app.get("/health")
def health():
    return {"status": "ok"}
