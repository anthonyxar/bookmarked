// Real Firebase project config (bookmarked-87332), matching the
// google-services.json / GoogleService-Info.plist checked in alongside this
// file. Safe to commit — these are client identifiers, not secrets; access
// is enforced by Firestore/Storage Security Rules and App Check, not by
// keeping this file private.
//
// Everyday dev still runs against the Local Emulator Suite by default (see
// main.dart's USE_FIREBASE_EMULATOR flag) — these real values are only
// actually used when that's turned off, for on-device/production runs.
//
// Only Android and iOS are supported — this app doesn't target web or
// desktop (see docs/adr/0001-migrate-postgres-fastapi-to-firebase.md).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Web isn't a shipped target (see the ADR) — this branch exists only so
    // `flutter run -d web-server` can be used to dev-test provider/Firestore
    // logic in a browser against the emulator before app/web is removed.
    // Delete this branch along with app/web once that removal is approved.
    if (kIsWeb) return android;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ${defaultTargetPlatform.name} — '
          'this app only targets Android and iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBaXmdVJIqR82adqw_7b7RV9X7R1DMXhoM',
    appId: '1:387403379867:android:927bffc1488f105982c23e',
    messagingSenderId: '387403379867',
    projectId: 'bookmarked-87332',
    storageBucket: 'bookmarked-87332.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDxb31ESDApx4-rrJufRlrYqMruQO7mFUg',
    appId: '1:387403379867:ios:94a678be7a46346882c23e',
    messagingSenderId: '387403379867',
    projectId: 'bookmarked-87332',
    storageBucket: 'bookmarked-87332.firebasestorage.app',
    iosBundleId: 'com.bookmarked.bookmarked',
  );
}
