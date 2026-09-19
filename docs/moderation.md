# Moderation

How reporting, blocking and moderation work (issue #34). Rules and functions
changes need a manual deploy, see `AGENTS.md`.

## What users can do

- **Report** a club note, a member's review, a member, or a club: tap the
  "more" button on a note or review, tap a member's name in a club, or use
  "Report club" in the club's menu. They pick a reason (spam, abusive or
  hateful, inappropriate, impersonation, other) and can add up to 500
  characters of detail.
- **Block** someone from the same menus. A block hides that person's notes and
  reviews from the blocker and stops them from inviting the blocker to a club.
  Blocked people are listed under Profile > Blocked, with an Unblock button.
  It does **not** remove anyone from a club, and it is one-way: the blocked
  person can still see the blocker's notes.

## Where reports go

Each report is one document in the top-level `reports` collection, with id
`{reporterUid}__{type}__{targetId}` so the same person can't file the same
report twice. It holds the reporter, what and who was reported, the club, the
reason and details, and a **snapshot** of the reported text (so it still makes
sense if the content is later edited or deleted). Reporters can't read reports
back, and nothing edits them from the app: only moderators can read them, and
they are resolved only through the `resolveReport` function.

## Reviewing and acting

Moderators use **Profile > Moderation** in the app (it appears only for users
with the `admin` claim), or read the `reports` collection (filter
`status == open`) in the Firebase console. Per report, the actions are:

| Action | What it does |
| --- | --- |
| Dismiss | Marks the report resolved and changes nothing else. |
| Remove content | A **note**: deletes it. A **club**: clears its image and description and renames it "Removed by moderators". Not available for reviews or members. |
| Remove member | Sets the reported person's membership in that club to `removed`. Refuses if they own the club. |
| Suspend user | Disables their Firebase account and revokes their sessions. For a club report, this suspends the club's owner. |

Every action marks the report `resolved` and records `resolution`,
`resolvedBy` and `resolvedAt`. To undo a suspension, re-enable the user in the
Firebase console (Authentication).

## Making someone a moderator

Custom claims can only be set with the Admin SDK, so this needs credentials for
the real project. Create a service account key (Firebase console > Project
settings > Service accounts > Generate new private key), keep it **outside the
repo and never commit it**, and run:

```
docker compose run --rm --no-deps -v "C:/path/to/key.json:/key.json:ro" --entrypoint sh firebase -c "cd /workspace/functions && GOOGLE_APPLICATION_CREDENTIALS=/key.json node scripts/grant-admin.js someone@example.com"
```

Add `--revoke` to remove it. The person has to sign out and back in before the
Moderation card shows up. Delete the key file when you're done with it.

## Retention and privacy

Reports are kept after they are resolved, as a moderation record. They contain
the reporter's and the reported person's user ids and a copy of the reported
text. Deleting an account (#32) does not remove reports about or by that
person. The privacy policy (#33) should say this, and a retention period
should be decided.

Blocks store only a timestamp against the blocked person's uid, no name, so a
deleted account leaves nothing personal in anyone's block list.

## Not done yet

- **Terms acceptance** that covers user-generated content, and a **support
  email** shown to users, both wait on the terms and support page (#33).
- **Two-way hiding:** a blocked person can still see the blocker's notes.
- **Notifying moderators** of a new report: there is no push or email, so the
  Moderation screen has to be checked.
- **Abuse limits:** nothing stops someone filing many reports on different
  targets; App Check (#39) and rate limits would help.
- **Appeals:** there is no process for someone to contest an action.
