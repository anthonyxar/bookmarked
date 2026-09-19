"use strict";

// Grants (or revokes) the `admin` custom claim that makes someone a moderator
// (issue #34): it unlocks the Moderation screen and the resolveReport function.
// Custom claims can only be set with the Admin SDK, so this needs credentials
// for the real project — see docs/moderation.md.
//
//   node scripts/grant-admin.js <email>            grant
//   node scripts/grant-admin.js <email> --revoke   revoke
//
// The person has to sign out and back in before the change reaches the app.
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

const [email, flag] = process.argv.slice(2);
if (!email || (flag && flag !== "--revoke")) {
  console.error("usage: node scripts/grant-admin.js <email> [--revoke]");
  process.exit(1);
}

initializeApp({ projectId: process.env.GCLOUD_PROJECT || "bookmarked-87332" });

(async () => {
  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  const revoke = flag === "--revoke";
  // This replaces all of the user's custom claims; `admin` is the only one in use.
  await auth.setCustomUserClaims(user.uid, revoke ? null : { admin: true });
  await auth.revokeRefreshTokens(user.uid); // so a revoked moderator loses access promptly
  console.log(`${revoke ? "Revoked" : "Granted"} admin for ${email}. They need to sign out and back in.`);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
