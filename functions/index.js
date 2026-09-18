const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentDeleted } = require("firebase-functions/v2/firestore");

initializeApp();

// Narrow, minimum-privilege lookup: Firebase Auth's email index is admin-only,
// so a club invite (which is keyed by email, matching the old backend) has no
// client-side way to resolve "who is this email" without this. It does NOT
// check club membership/role — that's still enforced by Firestore Security
// Rules on the actual membership-document write the client makes afterward.
// See docs/adr/0001-migrate-postgres-fastapi-to-firebase.md and issue #23.
exports.lookupUserByEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const email = (request.data && request.data.email || "").trim().toLowerCase();
  if (!email) {
    throw new HttpsError("invalid-argument", "An email address is required.");
  }

  let userRecord;
  try {
    userRecord = await getAuth().getUserByEmail(email);
  } catch (e) {
    if (e.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "No Bookmarked user found with that email");
    }
    throw new HttpsError("internal", "Could not look up that email.");
  }

  const profileSnap = await getFirestore().collection("users").doc(userRecord.uid).get();
  const profile = profileSnap.data() || {};

  return {
    uid: userRecord.uid,
    name: profile.name || "Reader",
    avatarUrl: profile.avatarUrl || null,
  };
});

// Firestore doesn't cascade deletes: deleteClub in clubs_provider.dart only
// removes the clubs/{clubId} doc itself, leaving memberships, books (and
// their progress/notes), bingoTemplate, and memberBingo (and its squares)
// orphaned. This is pure hygiene, not integrity enforcement — the ADR's one
// carve-out for a Cloud Function that isn't a narrow lookup. See issue #17.
exports.cleanupClubSubcollections = onDocumentDeleted("clubs/{clubId}", async (event) => {
  const db = getFirestore();
  const clubRef = db.collection("clubs").doc(event.params.clubId);
  const subcollections = await clubRef.listCollections();
  await Promise.all(subcollections.map((col) => db.recursiveDelete(col)));
});

// Builds the club reviews list by matching every active member's personal
// `users/{uid}/books` against the club's current (or given) book by
// title+author, same as the retired backend's list_reviews. This has to be
// a Cloud Function rather than plain client Firestore reads: issue #9's
// rules only let a user read their own personal books collection, and
// loosening that so any club member could query another member's whole
// wishlist/journal would be a real privacy regression — narrow admin-
// privileged reads here avoid that. See issue #24 (filed while closing #14).
exports.listClubReviews = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const uid = request.auth.uid;
  const { clubId, clubBookId, override, limit, offset } = request.data || {};
  if (!clubId) {
    throw new HttpsError("invalid-argument", "clubId is required.");
  }

  const db = getFirestore();
  const clubRef = db.collection("clubs").doc(clubId);

  const myMembershipSnap = await clubRef.collection("memberships").doc(uid).get();
  const myMembership = myMembershipSnap.data();
  if (!myMembership || myMembership.status !== "active") {
    throw new HttpsError("permission-denied", "Not a member of this club.");
  }

  let bookSnap;
  if (clubBookId) {
    bookSnap = await clubRef.collection("books").doc(clubBookId).get();
    if (!bookSnap.exists) bookSnap = null;
  } else {
    const currentSnap = await clubRef.collection("books").where("isCurrent", "==", true).limit(1).get();
    bookSnap = currentSnap.docs[0] || null;
  }
  if (!bookSnap) {
    return { items: [], total: 0 };
  }
  const book = bookSnap.data();
  const titleLower = (book.title || "").toLowerCase();
  const authorLower = (book.author || "").toLowerCase();

  const myProgressSnap = await bookSnap.ref.collection("progress").doc(uid).get();
  const viewerFinished = myProgressSnap.data()?.finished === true;

  const activeMembersSnap = await clubRef.collection("memberships").where("status", "==", "active").get();

  const items = [];
  for (const membership of activeMembersSnap.docs) {
    const memberUid = membership.id;
    const isOwn = memberUid === uid;
    const profile = (await db.collection("users").doc(memberUid).get()).data() || {};

    const memberBooksSnap = await db.collection("users").doc(memberUid).collection("books").get();
    const reviewDoc = memberBooksSnap.docs.find((d) => {
      const data = d.data();
      return (data.title || "").toLowerCase() === titleLower && (data.author || "").toLowerCase() === authorLower;
    });
    const reviewBook = reviewDoc ? reviewDoc.data() : null;

    const hasReview = !!reviewBook && [
      reviewBook.rating != null,
      !!reviewBook.finalReview,
      !!reviewBook.likedMost,
      !!reviewBook.likedLeast,
      !!reviewBook.feel,
    ].some(Boolean);

    if (!hasReview) {
      // Nothing to show for someone else; for the viewer's own row, still
      // surface it so the app can offer to add/review this book.
      if (!isOwn) continue;
      items.push({
        user_id: memberUid, name: profile.name || "Reader", avatar_url: profile.avatarUrl || null,
        finished: false, locked: false, book_id: null,
      });
      continue;
    }

    // A viewer never needs a spoiler warning for their own review.
    const locked = !isOwn && !viewerFinished && !override;
    if (locked) {
      items.push({
        user_id: memberUid, name: profile.name || "Reader", avatar_url: profile.avatarUrl || null,
        finished: !!reviewBook.read, locked: true,
        spoiler_warning: "You haven't finished this book yet. Viewing may spoil it for you.",
      });
      continue;
    }

    items.push({
      user_id: memberUid, name: profile.name || "Reader", avatar_url: profile.avatarUrl || null,
      finished: !!reviewBook.read, locked: false,
      book_id: isOwn ? reviewDoc.id : null,
      rating: reviewBook.rating ?? null,
      rating_cover: reviewBook.ratingCover ?? null,
      rating_writing: reviewBook.ratingWriting ?? null,
      rating_plot: reviewBook.ratingPlot ?? null,
      rating_characters: reviewBook.ratingCharacters ?? null,
      enjoyed: reviewBook.enjoyed ?? null,
      read_again: reviewBook.readAgain ?? null,
      liked_most: reviewBook.likedMost ?? null,
      liked_least: reviewBook.likedLeast ?? null,
      feel: reviewBook.feel ?? null,
      trope: reviewBook.trope ?? null,
      final_review: reviewBook.finalReview ?? null,
      favorite_characters: reviewBook.favoriteCharacters ?? [],
      notable_scenes: reviewBook.notableScenes ?? [],
      quotes: reviewBook.quotes ?? [],
    });
  }

  const total = items.length;
  const pageOffset = offset || 0;
  const pageLimit = limit || 30;
  return { items: items.slice(pageOffset, pageOffset + pageLimit), total };
});

// Cloud Functions still to add here:
// - FCM push notification triggers (issue #18)
