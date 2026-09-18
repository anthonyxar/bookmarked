const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

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

// Cloud Functions still to add here:
// - recursive delete of a club's subcollections on club deletion (issue #17)
// - FCM push notification triggers (issue #18)
