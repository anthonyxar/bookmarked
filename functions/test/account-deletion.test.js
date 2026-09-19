// Tests for account deletion (issue #32). The pure helpers run anywhere; the
// integration test needs the Firestore, Auth and Storage emulators — run it with
//   firebase emulators:exec --only firestore,auth,storage --project demo-bookmarked \
//     'cd functions && npm test'
// and it is skipped when they aren't available.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { deleteAccountData, isRecentSignIn, pickSuccessor } = require("../account-deletion");

// ---------------------------------------------------------------- helpers ---

test("isRecentSignIn accepts a fresh sign-in and rejects a stale or missing one", () => {
  const now = 1_000_000;
  assert.equal(isRecentSignIn(now - 10, now), true);
  assert.equal(isRecentSignIn(now - 300, now), true); // exactly at the limit
  assert.equal(isRecentSignIn(now - 301, now), false);
  assert.equal(isRecentSignIn(undefined, now), false);
  assert.equal(isRecentSignIn("1000", now), false);
});

test("pickSuccessor prefers an admin, then the longest-standing member", () => {
  const member = (uid, role, status, joinedAtMillis) => ({ uid, role, status, joinedAtMillis });
  const members = [
    member("owner", "owner", "active", 1),
    member("early", "member", "active", 10),
    member("lateAdmin", "admin", "active", 500),
    member("earlyAdmin", "admin", "active", 100),
    member("invited", "admin", "invited", 5),
    member("removed", "admin", "removed", 5),
  ];
  assert.equal(pickSuccessor(members, "owner"), "earlyAdmin");
  assert.equal(pickSuccessor(members.filter((m) => m.role !== "admin"), "owner"), "early");
});

test("pickSuccessor ignores the leaving user and non-active members, and is null when nobody is left", () => {
  assert.equal(pickSuccessor([{ uid: "owner", role: "owner", status: "active", joinedAtMillis: 1 }], "owner"), null);
  assert.equal(pickSuccessor([{ uid: "x", role: "member", status: "invited", joinedAtMillis: 1 }], "owner"), null);
  assert.equal(pickSuccessor([], "owner"), null);
});

test("pickSuccessor is deterministic when nothing else separates two members", () => {
  const a = { uid: "b-user", role: "member", status: "active" };
  const b = { uid: "a-user", role: "member", status: "active" };
  assert.equal(pickSuccessor([a, b], "owner"), "a-user");
  assert.equal(pickSuccessor([b, a], "owner"), "a-user");
});

// ------------------------------------------------------------ integration ---

const haveEmulators = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST && process.env.FIREBASE_STORAGE_EMULATOR_HOST,
);

test("deleting an account removes everything it owns and leaves other people's data alone", { skip: !haveEmulators }, async () => {
  initializeApp({ projectId: "demo-bookmarked", storageBucket: "demo-bookmarked.appspot.com" });
  const db = getFirestore();
  const auth = getAuth();
  const bucket = getStorage().bucket();

  const at = (ms) => Timestamp.fromMillis(ms);
  const put = (path, data) => db.doc(path).set(data);

  for (const uid of ["alice", "bob", "carol", "dave", "eve"]) {
    await auth.createUser({ uid, email: `${uid}@example.com` });
    await put(`users/${uid}`, { name: uid });
  }

  // Alice's own data: profile subcollections, private tokens, avatar.
  await put("users/alice/books/b1", { title: "Mine" });
  await put("users/alice/bingoCards/2026", { year: 2026 });
  await put("users/alice/bingoCards/2026/squares/0", { label: "x" });
  await put("users/alice/monthlyFavorites/2026/months/1", { bookId: "b1" });
  await put("users/alice/bracketPicks/2026/matches/m1", { bookId: "b1" });
  await put("users/alice/fcmTokens/tok-1", { createdAt: at(1) });
  await bucket.file("avatars/alice").save("img", { contentType: "image/png" });
  await bucket.file("avatars/bob").save("img", { contentType: "image/png" });

  // clubSolo: alice owns it and nobody else is active (eve only has an invite),
  // so it should be deleted outright, with its image.
  await put("clubs/clubSolo", { name: "Solo", ownerId: "alice" });
  await put("clubs/clubSolo/memberships/alice", { userId: "alice", role: "owner", status: "active", joinedAt: at(1) });
  await put("clubs/clubSolo/memberships/eve", { userId: "eve", role: "member", status: "invited", invitedById: "alice" });
  await put("clubs/clubSolo/books/book1", { title: "Pick", isCurrent: true });
  await put("clubs/clubSolo/books/book1/progress/alice", { currentChapter: 3 });
  await put("clubs/clubSolo/memberBingo/alice", { wonAt: null });
  await put("clubs/clubSolo/memberBingo/alice/squares/0", { label: "x" });
  await put("clubs/clubSolo/bingoTemplate/0", { label: "x" });
  await bucket.file("clubImages/clubSolo").save("img", { contentType: "image/png" });

  // clubShared: alice owns it; bob (member, joined first) and carol (admin,
  // joined later) are active. Carol should inherit it as an admin.
  await put("clubs/clubShared", { name: "Shared", ownerId: "alice" });
  await put("clubs/clubShared/memberships/alice", { userId: "alice", role: "owner", status: "active", joinedAt: at(1) });
  await put("clubs/clubShared/memberships/bob", { userId: "bob", role: "member", status: "active", joinedAt: at(10) });
  await put("clubs/clubShared/memberships/carol", { userId: "carol", role: "admin", status: "active", joinedAt: at(500) });
  await put("clubs/clubShared/books/book1", { title: "Pick", isCurrent: true });
  await put("clubs/clubShared/books/book1/progress/alice", { currentChapter: 5 });
  await put("clubs/clubShared/books/book1/progress/bob", { currentChapter: 2 });
  await put("clubs/clubShared/books/book1/notes/n1", { userId: "alice", chapter: 1, body: "alice note" });
  await put("clubs/clubShared/books/book1/notes/n2", { userId: "bob", chapter: 1, body: "bob note" });
  await put("clubs/clubShared/memberBingo/alice", { wonAt: null });
  await put("clubs/clubShared/memberBingo/alice/squares/0", { label: "x" });
  await put("clubs/clubShared/memberBingo/bob", { wonAt: null });
  await put("clubs/clubShared/memberBingo/bob/squares/0", { label: "y" });
  await bucket.file("clubImages/clubShared").save("img", { contentType: "image/png" });

  // clubOther: dave owns it and alice is just a member.
  await put("clubs/clubOther", { name: "Other", ownerId: "dave" });
  await put("clubs/clubOther/memberships/dave", { userId: "dave", role: "owner", status: "active", joinedAt: at(1) });
  await put("clubs/clubOther/memberships/alice", { userId: "alice", role: "member", status: "active", joinedAt: at(20) });
  await put("clubs/clubOther/books/book1", { title: "Pick", isCurrent: true });
  await put("clubs/clubOther/books/book1/progress/alice", { currentChapter: 1 });
  await put("clubs/clubOther/books/book1/progress/dave", { currentChapter: 4 });
  await put("clubs/clubOther/books/book1/notes/n3", { userId: "alice", chapter: 1, body: "alice again" });
  await put("clubs/clubOther/books/book1/notes/n4", { userId: "dave", chapter: 1, body: "dave note" });
  await put("clubs/clubOther/memberBingo/alice", { wonAt: null });
  await put("clubs/clubOther/memberBingo/dave", { wonAt: null });

  const summary = await deleteAccountData({ db, bucket, auth, uid: "alice" });
  assert.deepEqual(summary, { clubsDeleted: 1, ownershipTransfers: 1 });

  const exists = async (path) => (await db.doc(path).get()).exists;
  const fileExists = async (path) => (await bucket.file(path).exists())[0];

  // Alice's profile and every subcollection under it.
  assert.equal(await exists("users/alice"), false);
  assert.deepEqual(await db.doc("users/alice").listCollections(), []);
  assert.equal(await fileExists("avatars/alice"), false);
  await assert.rejects(auth.getUser("alice"), { code: "auth/user-not-found" });

  // The club she owned alone is gone, including its subcollections and image.
  assert.equal(await exists("clubs/clubSolo"), false);
  assert.deepEqual(await db.doc("clubs/clubSolo").listCollections(), []);
  assert.equal(await fileExists("clubImages/clubSolo"), false);

  // The shared club passes to carol; alice's traces are gone, bob's are not.
  const shared = (await db.doc("clubs/clubShared").get()).data();
  assert.equal(shared.ownerId, "carol");
  assert.equal((await db.doc("clubs/clubShared/memberships/carol").get()).data().role, "owner");
  assert.equal((await db.doc("clubs/clubShared/memberships/bob").get()).data().role, "member");
  assert.equal(await exists("clubs/clubShared/memberships/alice"), false);
  assert.equal(await exists("clubs/clubShared/books/book1/progress/alice"), false);
  assert.equal(await exists("clubs/clubShared/books/book1/progress/bob"), true);
  assert.equal(await exists("clubs/clubShared/books/book1/notes/n1"), false);
  assert.equal(await exists("clubs/clubShared/books/book1/notes/n2"), true);
  assert.equal(await exists("clubs/clubShared/memberBingo/alice"), false);
  assert.equal((await db.collection("clubs/clubShared/memberBingo/alice/squares").get()).empty, true);
  assert.equal(await exists("clubs/clubShared/memberBingo/bob"), true);
  assert.equal(await fileExists("clubImages/clubShared"), true);

  // A club she was only a member of keeps its owner and everyone else's data.
  assert.equal((await db.doc("clubs/clubOther").get()).data().ownerId, "dave");
  assert.equal(await exists("clubs/clubOther/memberships/alice"), false);
  assert.equal(await exists("clubs/clubOther/memberships/dave"), true);
  assert.equal(await exists("clubs/clubOther/books/book1/progress/alice"), false);
  assert.equal(await exists("clubs/clubOther/books/book1/progress/dave"), true);
  assert.equal(await exists("clubs/clubOther/books/book1/notes/n3"), false);
  assert.equal(await exists("clubs/clubOther/books/book1/notes/n4"), true);
  assert.equal(await exists("clubs/clubOther/memberBingo/alice"), false);
  assert.equal(await exists("clubs/clubOther/memberBingo/dave"), true);

  // No membership row anywhere still points at her.
  assert.equal((await db.collectionGroup("memberships").where("userId", "==", "alice").get()).empty, true);

  // Other people are untouched.
  assert.equal(await exists("users/bob"), true);
  assert.equal(await fileExists("avatars/bob"), true);
  assert.equal((await auth.getUser("bob")).uid, "bob");

  // Running it again (a retry after a partial failure) is harmless.
  assert.deepEqual(await deleteAccountData({ db, bucket, auth, uid: "alice" }), { clubsDeleted: 0, ownershipTransfers: 0 });
});
