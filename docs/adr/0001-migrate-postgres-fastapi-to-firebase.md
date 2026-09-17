# Migrate from Postgres/FastAPI/JWT to Firebase (Firestore, Auth, Storage, Functions)

Status: accepted

The app is pre-launch with no real user data, and the goal is to eliminate backend hosting entirely while gaining realtime sync, offline support, and push notifications for free. We're replacing the FastAPI backend, Postgres, and custom JWT/bcrypt auth with a fully serverless architecture: the Flutter client talks directly to Firestore and Firebase Auth, with Cloud Functions used only where Firestore genuinely can't do the job (recursive delete on club deletion, FCM push triggers) rather than as a general home for business logic.

## Considered options

- **Keep FastAPI, swap Postgres for Firestore underneath it.** Rejected — keeps all the operational cost/maintenance of running a server while giving up Firestore's client-SDK realtime/offline benefits, which was the actual point of moving.
- **Server-authoritative Cloud Functions for game-integrity logic** (bracket advancement, bingo win detection, membership role changes). Rejected for now — this is a small club of trusted people, not a public product; Firestore Security Rules are enough to prevent accidental corruption, and a determined member tampering with their own client isn't a threat worth paying (in complexity or Blaze cost) to prevent yet. Revisit if the app is ever opened to untrusted users.
- **Hard spend cap on Blaze billing.** Not possible — Firebase has no true hard cap; the closest options are billing alerts (notify only, hours of lag) or a self-built Cloud Function that disables billing entirely (kills the whole GCP project, not just Firebase). We're using Blaze + budget alerts and accepting that residual risk, since Blaze retains the same free daily quotas as Spark and this app's usage is expected to stay near zero cost.

## Consequences

- No relational integrity (FK cascades, unique constraints) from the database — these are replaced by Firestore document-ID conventions (e.g. `clubs/{id}/memberships/{uid}`) where possible, and by a Cloud Function for recursive subcollection cleanup where not.
- Firestore is not stable on Linux/Windows desktop (only Auth/Core are); this is acceptable because the app targets Android/iOS only going forward, not desktop.
- Because there's no backend, invite-by-email only works for users who've already registered (unchanged from today) — inviting a not-yet-registered email is a deliberately deferred feature, not a limitation of Firebase.
