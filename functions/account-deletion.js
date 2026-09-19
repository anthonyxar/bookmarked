"use strict";

// Deleting an account (issue #32): the profile and everything under it, the
// avatar, the user's traces inside every club, clubs they own, and finally the
// Auth user. The Auth user goes last on purpose — it's what lets them call
// deleteMyAccount, so a failure part-way leaves them able to retry, and every
// step here is safe to run again.

// The callable insists the sign-in behind the ID token is at most this old, so
// a stolen or left-open session can't delete an account without a fresh login.
const RECENT_SIGN_IN_SECONDS = 5 * 60;

function isRecentSignIn(authTimeSeconds, nowSeconds = Date.now() / 1000, maxAgeSeconds = RECENT_SIGN_IN_SECONDS) {
  return typeof authTimeSeconds === "number" && nowSeconds - authTimeSeconds <= maxAgeSeconds;
}

// Who inherits a club when its owner leaves: an active admin first, then the
// longest-standing active member, with the uid as a last, deterministic
// tie-break. `members` are { uid, role, status, joinedAtMillis }. Null means
// nobody is left, i.e. the club should be deleted.
function pickSuccessor(members, leavingUid) {
  const rank = (m) => (m.role === "admin" ? 0 : 1);
  const joined = (m) => (typeof m.joinedAtMillis === "number" ? m.joinedAtMillis : Number.MAX_SAFE_INTEGER);
  const candidates = members.filter((m) => m.uid !== leavingUid && m.status === "active");
  if (candidates.length === 0) return null;
  candidates.sort((a, b) => rank(a) - rank(b) || joined(a) - joined(b) || (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0));
  return candidates[0].uid;
}

// Deletes a whole club: the doc, every subcollection, and its image. The
// cleanupClubSubcollections trigger would also clear the subcollections
// afterwards; doing it here keeps the result immediate and deterministic.
async function deleteClub(db, bucket, clubRef) {
  await db.recursiveDelete(clubRef);
  await deleteClubImage(bucket, clubRef.id);
}

async function deleteClubImage(bucket, clubId) {
  await bucket.file(`clubImages/${clubId}`).delete({ ignoreNotFound: true });
}

// Removes one user's traces from one club, first handing the club to someone
// else if they own it. Returns "deleted" if the club had nobody left and was
// deleted, "transferred" if ownership moved, otherwise null.
async function removeFromClub(db, bucket, clubRef, uid) {
  let outcome = null;

  const clubSnap = await clubRef.get();
  if (clubSnap.exists && clubSnap.data().ownerId === uid) {
    const memberSnaps = await clubRef.collection("memberships").get();
    const members = memberSnaps.docs.map((d) => ({
      uid: d.id,
      role: d.data().role,
      status: d.data().status,
      joinedAtMillis: d.data().joinedAt ? d.data().joinedAt.toMillis() : undefined,
    }));
    const successor = pickSuccessor(members, uid);
    if (successor === null) {
      await deleteClub(db, bucket, clubRef);
      return "deleted";
    }
    // Same shape as the app's own ownership transfer: the club's ownerId and
    // the new owner's membership role change together.
    const batch = db.batch();
    batch.update(clubRef, { ownerId: successor });
    batch.update(clubRef.collection("memberships").doc(successor), { role: "owner" });
    await batch.commit();
    outcome = "transferred";
  }

  await clubRef.collection("memberships").doc(uid).delete();
  await db.recursiveDelete(clubRef.collection("memberBingo").doc(uid)); // the card and its squares
  const books = await clubRef.collection("books").get();
  for (const book of books.docs) {
    await book.ref.collection("progress").doc(uid).delete();
    const notes = await book.ref.collection("notes").where("userId", "==", uid).get();
    await Promise.all(notes.docs.map((n) => n.ref.delete()));
  }
  return outcome;
}

async function deleteAccountData({ db, bucket, auth, uid }) {
  const summary = { clubsDeleted: 0, ownershipTransfers: 0 };

  // Every membership row, whatever its status (active, invited, declined,
  // removed): the user shouldn't linger in any club's records.
  const memberships = await db.collectionGroup("memberships").where("userId", "==", uid).get();
  for (const m of memberships.docs) {
    const outcome = await removeFromClub(db, bucket, m.ref.parent.parent, uid);
    if (outcome === "deleted") summary.clubsDeleted += 1;
    if (outcome === "transferred") summary.ownershipTransfers += 1;
  }

  // The profile doc and all its subcollections: books, bingo cards, monthly
  // favourites, bracket picks, and the private push tokens.
  await db.recursiveDelete(db.collection("users").doc(uid));
  await bucket.file(`avatars/${uid}`).delete({ ignoreNotFound: true });

  try {
    await auth.deleteUser(uid);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }
  return summary;
}

module.exports = { RECENT_SIGN_IN_SECONDS, isRecentSignIn, pickSuccessor, deleteClubImage, deleteAccountData };
