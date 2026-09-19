# Bookmarked — agent notes

A reading journal app (wishlist, journal reviews, dashboard, bingo, book
clubs) on a fully serverless Firebase stack (Firestore, Firebase Auth, Cloud
Storage, Cloud Functions, FCM), migrated from Postgres/FastAPI/JWT. See
`docs/adr/0001-migrate-postgres-fastapi-to-firebase.md` for why, and GitHub
issue #4 (label `firebase-migration`) for the tracking issue.

## Migration status

The FastAPI/Postgres backend is gone (deleted in issue #20; last present at
commit `99e92f1`, so `git show 99e92f1:backend/<path>` recovers the old
logic). All work goes through Firestore/Cloud Functions directly from the
Flutter client; do not add REST endpoints or a new server.

The migration is finished: every `firebase-migration` issue, including the
tracking issue #4, is closed. Nothing deploys automatically — rules, indexes,
storage rules and functions reach the real project (`bookmarked-87332`) only
through a manual `firebase deploy --project bookmarked-87332` (interactive
login, run from the `firebase` service). Work that needs Firebase console
access (providers, billing, App Check, deploys) — flag it rather than
attempting it blind. The project has a Firebase spend cap that pauses services
when exceeded (a cap of zero trips on the first cent — see the spend-cap
correction in the ADR).

## Tooling — Docker only

No local Flutter install is assumed or required. Everything runs
through `docker compose`. Verify Flutter changes with:

```bash
docker compose run --rm --no-deps app sh -c "flutter pub get && flutter analyze"
```

The `app` service is only a workspace (no dev server — there's no device in the
container). Its `~/.android` is mounted from the gitignored `keystore/` dir so
APKs are always signed with the same debug key; the SHA-1/SHA-256 of
`keystore/debug.keystore` are what's registered in the Firebase console for
Google Sign-In. Without that mount the key is regenerated per container and
sign-in on Android fails with DEVELOPER_ERROR (code 10). Recreate the keystore
with `keytool -genkeypair` (alias `androiddebugkey`, password `android`) and
register the new fingerprints if `keystore/` is ever lost.

Firebase Local Emulator Suite (`firebase` service) is the whole local
backend: Auth (9099), Firestore (8080), Storage
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
  section before adding one. The Firestore database and all functions live in
  `australia-southeast1` (Firestore triggers must share the database's
  region): set once via `setGlobalOptions` in `functions/index.js`, and the app
  must call functions through `appFunctions` (`app/lib/utils/app_functions.dart`),
  never `FirebaseFunctions.instance` (defaults to us-central1 → "not found").
- Desktop Flutter targets (`linux/`, `macos/`, `windows/`) and web are being
  dropped — Firestore isn't stable there and the app is Android/iOS only
  going forward (issue #7). Don't fix desktop-specific build breakage; raise
  whether to delete those platform folders instead.
- Firebase migration commits close their GitHub issue in the same commit
  message (`Closes #N`) — keep following that pattern for traceability
  against the tracking issue.
