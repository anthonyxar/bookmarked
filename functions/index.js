const { initializeApp } = require("firebase-admin/app");

initializeApp();

// Cloud Functions land here:
// - recursive delete of a club's subcollections on club deletion (issue #17)
// - FCM push notification triggers (issue #18)
// No functions are exported yet.
