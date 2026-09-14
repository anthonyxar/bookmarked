from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import auth, bingo, books, dashboard, users

app = FastAPI(title="Bookmarked API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(books.router)
app.include_router(bingo.router)
app.include_router(dashboard.router)


@app.get("/health")
def health():
    return {"status": "ok"}
