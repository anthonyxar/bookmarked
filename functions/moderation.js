"use strict";

// Moderation (issue #34): reading a user's block list, and applying an admin's
// decision to a user-filed report. Reports themselves are written by the app
// (see the `reports` rules); everything an admin does to one goes through
// resolveReport so it always runs with the Admin SDK and leaves a record.

const { FieldValue } = require("firebase-admin/firestore");

const ACTIONS = ["dismiss", "removeContent", "removeMember", "suspendUser"];

// Carries an HttpsError code so index.js can turn it into the right response
// without this module depending on firebase-functions.
class ModerationError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

// The uids `uid` has blocked (users/{uid}/blocks/{blockedUid}).
async function blockedIdsFor(db, uid) {
  const snap = await db.collection("users").doc(uid).collection("blocks").get();
  return new Set(snap.docs.map((d) => d.id));
}

async function removeContent({ db, bucket, report }) {
  if (report.type === "note") {
    if (!report.clubId || !report.bookId || !report.targetId) {
      throw new ModerationError("invalid-argument", "That report doesn't say which note it is.");
    }
    await db.doc(`clubs/${report.clubId}/books/${report.bookId}/notes/${report.targetId}`).delete();
    return;
  }
  if (report.type === "club") {
    const clubRef = db.collection("clubs").doc(report.clubId);
    if ((await clubRef.get()).exists) {
      // The name is required by the app, so it's replaced, not blanked.
      await clubRef.update({ imageUrl: null, description: null, name: "Removed by moderators" });
    }
    await bucket.file(`clubImages/${report.clubId}`).delete({ ignoreNotFound: true });
    return;
  }
  // A review is a member's own private book entry, and a member is a person:
  // neither can be "removed" as content. Remove the member or suspend them.
  throw new ModerationError(
    "failed-precondition",
    "Reviews and members can't be removed as content. Remove the member from the club or suspend the user instead.",
  );
}

async function removeMember({ db, report }) {
  if (!report.clubId || !report.targetUserId) {
    throw new ModerationError("invalid-argument", "That report doesn't name a member of a club.");
  }
  const clubRef = db.collection("clubs").doc(report.clubId);
  const club = (await clubRef.get()).data();
  if (club && club.ownerId === report.targetUserId) {
    throw new ModerationError("failed-precondition", "That person owns the club. Suspend them or remove the content instead.");
  }
  const memberRef = clubRef.collection("memberships").doc(report.targetUserId);
  if ((await memberRef.get()).exists) await memberRef.update({ status: "removed" });
}

async function suspendUser({ db, auth, report }) {
  let target = report.targetUserId;
  if (!target && report.type === "club") {
    // A report about a club is about whoever runs it.
    target = ((await db.collection("clubs").doc(report.clubId).get()).data() || {}).ownerId;
  }
  if (!target) throw new ModerationError("invalid-argument", "That report doesn't identify a user to suspend.");
  await auth.updateUser(target, { disabled: true });
  await auth.revokeRefreshTokens(target);
}

// Applies `action` to the open report `reportId` and marks it resolved.
async function resolveReport({ db, auth, bucket, reportId, action, adminUid }) {
  if (!ACTIONS.includes(action)) throw new ModerationError("invalid-argument", "Unknown action.");
  const reportRef = db.collection("reports").doc(String(reportId));
  const snap = await reportRef.get();
  if (!snap.exists) throw new ModerationError("not-found", "No such report.");
  const report = snap.data();
  if (report.status !== "open") throw new ModerationError("failed-precondition", "That report is already resolved.");

  if (action === "removeContent") await removeContent({ db, bucket, report });
  if (action === "removeMember") await removeMember({ db, report });
  if (action === "suspendUser") await suspendUser({ db, auth, report });

  await reportRef.update({
    status: "resolved",
    resolution: action,
    resolvedBy: adminUid,
    resolvedAt: FieldValue.serverTimestamp(),
  });
  return { action };
}

module.exports = { ACTIONS, ModerationError, blockedIdsFor, resolveReport };
