// Tests for moderation (issue #34): reading a user's block list and applying an
// admin's decision to a report. Needs the Firestore, Auth and Storage emulators:
//   firebase emulators:exec --only firestore,auth,storage --project demo-bookmarked \
//     'cd functions && npm test'
// and is skipped when they aren't available.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { ModerationError, blockedIdsFor, resolveReport } = require("../moderation");

const haveEmulators = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST && process.env.FIREBASE_STORAGE_EMULATOR_HOST,
);

test("moderation: blocks and admin actions", { skip: !haveEmulators }, async (t) => {
  initializeApp({ projectId: "demo-bookmarked", storageBucket: "demo-bookmarked.appspot.com" });
  const db = getFirestore();
  const auth = getAuth();
  const bucket = getStorage().bucket();
  const ctx = { db, auth, bucket, adminUid: "mod-root" };

  const put = (path, data) => db.doc(path).set(data);
  const exists = async (path) => (await db.doc(path).get()).exists;
  const report = (id, over = {}) =>
    put(`reports/${id}`, {
      reporterId: "mod-bob", type: "note", targetId: "n1", clubId: "modclub1", targetUserId: "mod-alice", bookId: "book1",
      reason: "abuse", details: "", snapshot: "rude", status: "open", createdAt: Timestamp.now(), ...over,
    });
  const rejects = (promise, code) => assert.rejects(promise, (e) => e instanceof ModerationError && e.code === code);

  for (const uid of ["mod-alice", "mod-bob", "mod-carol", "mod-root"]) await auth.createUser({ uid, email: `${uid}@example.com` });
  await put("clubs/modclub1", { name: "Club", description: "About us", imageUrl: "https://x/y.png", ownerId: "mod-carol" });
  await put("clubs/modclub1/memberships/mod-carol", { userId: "mod-carol", role: "owner", status: "active" });
  await put("clubs/modclub1/memberships/mod-alice", { userId: "mod-alice", role: "member", status: "active" });
  await put("clubs/modclub1/memberships/mod-bob", { userId: "mod-bob", role: "member", status: "active" });
  await put("clubs/modclub1/books/book1/notes/n1", { userId: "mod-alice", chapter: 1, body: "rude" });
  await put("clubs/modclub1/books/book1/notes/n2", { userId: "mod-bob", chapter: 1, body: "fine" });
  await bucket.file("clubImages/modclub1").save("img", { contentType: "image/png" });

  await t.test("blockedIdsFor returns the ids a user has blocked, and nothing for someone with no blocks", async () => {
    await put("users/mod-bob/blocks/mod-alice", { createdAt: Timestamp.now() });
    await put("users/mod-bob/blocks/mod-dave", { createdAt: Timestamp.now() });
    assert.deepEqual([...(await blockedIdsFor(db, "mod-bob"))].sort(), ["mod-alice", "mod-dave"]);
    assert.equal((await blockedIdsFor(db, "mod-carol")).size, 0);
  });

  await t.test("dismiss resolves the report and touches nothing else", async () => {
    await report("r-dismiss");
    assert.deepEqual(await resolveReport({ ...ctx, reportId: "r-dismiss", action: "dismiss" }), { action: "dismiss" });
    const r = (await db.doc("reports/r-dismiss").get()).data();
    assert.equal(r.status, "resolved");
    assert.equal(r.resolution, "dismiss");
    assert.equal(r.resolvedBy, "mod-root");
    assert.ok(r.resolvedAt);
    assert.equal(await exists("clubs/modclub1/books/book1/notes/n1"), true);
  });

  await t.test("removeContent deletes the reported note and only that note", async () => {
    await report("r-note");
    await resolveReport({ ...ctx, reportId: "r-note", action: "removeContent" });
    assert.equal(await exists("clubs/modclub1/books/book1/notes/n1"), false);
    assert.equal(await exists("clubs/modclub1/books/book1/notes/n2"), true);
    assert.equal((await db.doc("reports/r-note").get()).data().status, "resolved");
  });

  await t.test("removeContent on a review or a member is refused and leaves the report open", async () => {
    await report("r-review", { type: "review", targetId: "mod-alice", bookId: null });
    await rejects(resolveReport({ ...ctx, reportId: "r-review", action: "removeContent" }), "failed-precondition");
    await report("r-member", { type: "member", targetId: "mod-alice", bookId: null });
    await rejects(resolveReport({ ...ctx, reportId: "r-member", action: "removeContent" }), "failed-precondition");
    assert.equal((await db.doc("reports/r-review").get()).data().status, "open");
    assert.equal((await db.doc("reports/r-member").get()).data().status, "open");
  });

  await t.test("removeMember marks the reported member as removed but refuses to remove the owner", async () => {
    await resolveReport({ ...ctx, reportId: "r-member", action: "removeMember" });
    assert.equal((await db.doc("clubs/modclub1/memberships/mod-alice").get()).data().status, "removed");
    assert.equal((await db.doc("clubs/modclub1/memberships/mod-bob").get()).data().status, "active");

    await report("r-owner", { type: "member", targetId: "mod-carol", targetUserId: "mod-carol", bookId: null });
    await rejects(resolveReport({ ...ctx, reportId: "r-owner", action: "removeMember" }), "failed-precondition");
    assert.equal((await db.doc("clubs/modclub1/memberships/mod-carol").get()).data().status, "active");
  });

  await t.test("suspendUser disables the reported user's account", async () => {
    await resolveReport({ ...ctx, reportId: "r-review", action: "suspendUser" });
    assert.equal((await auth.getUser("mod-alice")).disabled, true);
    assert.equal((await auth.getUser("mod-bob")).disabled, false);
  });

  await t.test("removeContent on a club clears its image, description and name", async () => {
    await report("r-club", { type: "club", targetId: "modclub1", targetUserId: null, bookId: null });
    await resolveReport({ ...ctx, reportId: "r-club", action: "removeContent" });
    const club = (await db.doc("clubs/modclub1").get()).data();
    assert.equal(club.imageUrl, null);
    assert.equal(club.description, null);
    assert.equal(club.name, "Removed by moderators");
    assert.equal((await bucket.file("clubImages/modclub1").exists())[0], false);
  });

  await t.test("suspending over a club report suspends the club's owner", async () => {
    await report("r-club2", { type: "club", targetId: "modclub1", targetUserId: null, bookId: null });
    await resolveReport({ ...ctx, reportId: "r-club2", action: "suspendUser" });
    assert.equal((await auth.getUser("mod-carol")).disabled, true);
  });

  await t.test("bad requests: unknown action, missing report, and an already-resolved report", async () => {
    await report("r-bad");
    await rejects(resolveReport({ ...ctx, reportId: "r-bad", action: "explode" }), "invalid-argument");
    await rejects(resolveReport({ ...ctx, reportId: "nope", action: "dismiss" }), "not-found");
    await rejects(resolveReport({ ...ctx, reportId: "r-dismiss", action: "dismiss" }), "failed-precondition");
    assert.equal((await db.doc("reports/r-bad").get()).data().status, "open");
  });
});
