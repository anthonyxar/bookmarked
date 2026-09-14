# Bookmarked

A reading journal app: wishlist tracking, journal-style book reviews, a reading
dashboard, and reading bingo — all per-user.

## Stack

- **`app/`** — Flutter (mobile + web), Riverpod for state, talks to the backend over REST.
- **`backend/`** — FastAPI + SQLAlchemy + Alembic, JWT auth, Postgres for storage.
- **`docker-compose.yml`** — runs Postgres, the backend API, and a Flutter web dev
  server together, so nothing needs installing locally except Docker.

## Running it locally

```bash
cp .env.example .env
docker compose up
```

- Backend API: http://localhost:8000 (docs at `/docs`)
- Flutter web app: http://localhost:5000
- Postgres: localhost:5432 (`bookmarked` / `bookmarked`)

The backend runs Alembic migrations automatically on startup. The Flutter
container runs `flutter run -d web-server` with hot reload — edit files under
`app/lib` and the browser updates.

To run just one piece:

```bash
docker compose up -d db backend   # API only
docker compose up app             # Flutter web only (needs backend running)
```

## Building for a real device

The Docker `app` service targets **web** for fast local iteration without
needing the Flutter SDK installed. To run on an iOS/Android device or
simulator, install the Flutter SDK locally and point `--dart-define=API_BASE_URL`
at your backend's reachable address:

```bash
cd app
flutter run --dart-define=API_BASE_URL=http://<your-machine-ip>:8000
```

## Backend

- Auth: `POST /auth/register`, `POST /auth/login`, `GET /auth/me` (JWT bearer tokens)
- Wishlist: `GET/POST /books`, `GET/PATCH/DELETE /books/{id}`
- Dashboard: `GET /dashboard`
- Bingo: `GET /bingo`, `PATCH /bingo/squares/{id}`, `POST /bingo/reset`

New migrations:

```bash
docker compose exec backend alembic revision -m "add something" --autogenerate
docker compose exec backend alembic upgrade head
```
