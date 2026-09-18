# Bookmarked — agent notes

A reading journal app (wishlist, journal reviews, dashboard, bingo, book
clubs) currently mid-migration from Postgres/FastAPI/JWT to a fully
serverless Firebase stack (Firestore, Firebase Auth, Cloud Storage, Cloud
Functions, FCM). See `docs/adr/0001-migrate-postgres-fastapi-to-firebase.md`
for why, and GitHub issue #4 (label `firebase-migration`) for the tracking
issue with all sub-issues.

## Migration status — read this before touching `backend/` or `app/lib`

`backend/` (FastAPI + Postgres) is being decommissioned, not extended. New
work goes through Firestore/Cloud Functions directly from the Flutter client;
do not add new REST endpoints. Both stacks run side by side in
`docker-compose.yml` until every domain is migrated and verified (issue #20
deletes `backend/` and the `db` service last).

Check open issues under the `firebase-migration` label before starting new
migration work — `gh issue list --label firebase-migration --state open`.
A `TODO(#N)` comment in `app/lib` points at the issue still blocking full
removal of the REST call it sits next to.

Some sub-issues need Firebase console access (enabling providers, Blaze
billing, budget alerts) rather than code — flag those rather than attempting
them blind.

## Tooling — Docker only

No local Flutter or Python install is assumed or required. Everything runs
through `docker compose`. Verify Flutter changes with:

```bash
docker compose run --rm --no-deps app sh -c "flutter pub get && flutter analyze"
```

The `app` service's default command runs the dev server in `--release` mode
(`docker-compose.yml`) — a prior debug-mode config caused recurring blank-
screen hangs, so don't revert that.

Firebase Local Emulator Suite (`firebase` service) replaces `db`+`backend`
for anything already migrated: Auth (9099), Firestore (8080), Storage
(9199), Functions (5001), emulator UI (4000). Functions require
`npm install` inside `functions/` (already committed as
`functions/package-lock.json`) or the emulator warns on boot.

## Conventions

- Firestore documents use ID conventions in place of the FK/unique
  constraints Postgres gave up (e.g. `clubs/{clubId}/memberships/{uid}`,
  `users/{uid}/bracketPicks/{year}_{matchId}`) — check a domain's migration
  issue for the exact collection layout before inventing a new shape.
- Cloud Functions are for what Firestore Security Rules genuinely can't do
  (recursive subcollection delete, admin-only email lookup, FCM triggers) —
  not a general home for business logic. See the ADR's "Consequences"
  section before adding one.
- Desktop Flutter targets (`linux/`, `macos/`, `windows/`) and web are being
  dropped — Firestore isn't stable there and the app is Android/iOS only
  going forward (issue #7). Don't fix desktop-specific build breakage; raise
  whether to delete those platform folders instead.
- Firebase migration commits close their GitHub issue in the same commit
  message (`Closes #N`) — keep following that pattern for traceability
  against the tracking issue.
