"""Minimal in-memory rate limiting for sensitive endpoints (login/register).

Deliberately dependency-free and process-local: fine for this app's single
-worker dev/small-deployment setup, but note it does NOT share state across
multiple uvicorn/gunicorn workers or hosts. If the backend is ever scaled
horizontally, replace this with a shared store (e.g. Redis-backed limiter).
"""
import time
from collections import defaultdict
from threading import Lock

from fastapi import HTTPException, Request, status


class RateLimiter:
    def __init__(self, max_attempts: int, window_seconds: int):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self._hits: dict[str, list[float]] = defaultdict(list)
        self._lock = Lock()

    def __call__(self, request: Request) -> None:
        key = request.client.host if request.client else "unknown"
        now = time.monotonic()
        cutoff = now - self.window_seconds
        with self._lock:
            hits = self._hits[key]
            while hits and hits[0] < cutoff:
                hits.pop(0)
            if len(hits) >= self.max_attempts:
                raise HTTPException(
                    status.HTTP_429_TOO_MANY_REQUESTS,
                    "Too many attempts. Please wait a moment and try again.",
                )
            hits.append(now)


# 10 attempts per minute per client IP is generous enough for a mistyped
# password but blunts scripted brute-force / signup-spam attempts.
auth_rate_limiter = RateLimiter(max_attempts=10, window_seconds=60)
