import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'theme.dart';

// Defaults to the Local Emulator Suite (see firebase.json / docker-compose.yml).
// For a real Firebase project or a physical device that can't reach
// "localhost" (it means the device itself, not your dev machine), override
// both, e.g.:
//   flutter run --dart-define=FIREBASE_EMULATOR_HOST=<your-machine-lan-ip>
//   flutter run --dart-define=USE_FIREBASE_EMULATOR=false
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: true);
const firebaseEmulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (useFirebaseEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
    await FirebaseStorage.instance.useStorageEmulator(firebaseEmulatorHost, 9199);
    FirebaseFunctions.instance.useFunctionsEmulator(firebaseEmulatorHost, 5001);
  } else {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(const ProviderScope(child: BookmarkedApp()));
}

class BookmarkedApp extends StatelessWidget {
  const BookmarkedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookmarked',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
