# Bookmarked

A reading journal app: wishlist tracking, journal-style book reviews, a reading
dashboard, reading bingo, and book clubs — all per-user, Android/iOS only.

## Stack

- **`app/`** — Flutter (Android/iOS), Riverpod for state, talks directly to
  Firestore/Firebase Auth/Cloud Storage from the client.
- **`functions/`** — Cloud Functions for the handful of things Firestore
  Security Rules can't do (admin-only email lookup, recursive subcollection
  delete, the club reviews list, FCM push triggers).
- **`firestore.rules` / `storage.rules`** — Security Rules enforcing data
  shape and permissions; this is the trust boundary, not the Cloud Functions.
- **`docker-compose.yml`** — runs the Firebase Local Emulator Suite (Auth,
  Firestore, Storage, Functions) and a Flutter workspace container, so
  nothing needs installing locally except Docker.

See `docs/adr/0001-migrate-postgres-fastapi-to-firebase.md` for why this is a
serverless Firebase stack rather than a custom backend.

## Running it locally

```bash
docker compose up
```

- Emulator UI: http://localhost:4000 (Auth/Firestore/Storage/Functions data)
- Firestore: localhost:8080, Auth: localhost:9099, Storage: localhost:9199,
  Functions: localhost:5001

Emulator data persists across restarts (exported/imported automatically).

The `app` container isn't a live dev server — there's no Android/iOS
device or emulator inside it. It stays up as a workspace for ad hoc
commands:

```bash
docker compose run --rm --no-deps app sh -c "flutter pub get && flutter analyze"
docker compose run --rm --no-deps app sh -c "flutter build apk --debug"
```

Sideload the built APK over USB/adb from the host to test on a real device.
iOS needs Xcode on a real Mac — this Linux-based Docker image can't build it.

## Cloud Functions

- `lookupUserByEmail` — resolves a club invite's email to a uid (Firebase
  Auth's email index is admin-only; membership permission is still enforced
  by Security Rules on the write that follows).
- `cleanupClubSubcollections` — recursive delete of a club's subcollections
  on club deletion (Firestore doesn't cascade).
- `listClubReviews` — builds a club's reviews list across members' personal
  book collections (needs admin-privileged reads across users).
- `notifyClubInvite` / `notifyClubNewBook` — FCM push notification triggers.
- `deleteMyAccount` — permanently deletes the caller's account and data
  (profile, avatar, their traces in every club; clubs they own pass to another
  member or are deleted if nobody else is active). Requires a recent sign-in.

```bash
docker compose run --rm --no-deps --entrypoint sh firebase -c "cd functions && npm install"  # after editing functions/package.json
```

## Firebase project setup

`scripts/setup-firebase.sh` walks through the one-time console setup (Blaze
plan, budget alert, Android/iOS app registration, App Check) needed before
testing against a real Firebase project instead of the emulator.
