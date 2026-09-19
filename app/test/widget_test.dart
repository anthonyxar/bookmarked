import 'package:bookmarked/main.dart';
import 'package:bookmarked/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The app talks to Firebase from the moment its first screen builds, and tests
// don't have a Firebase app — so booting it used to fail with
// "[core/no-app] No Firebase App '[DEFAULT]'" (issue #44). This swaps the auth
// provider for a signed-out stub, which is all the first screen needs.
class _FakeFirebaseAuth extends Fake implements fb_auth.FirebaseAuth {
  @override
  Stream<fb_auth.User?> authStateChanges() => const Stream.empty();
}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _SignedOutAuth extends AuthNotifier {
  _SignedOutAuth() : super(_FakeFirebaseAuth(), _FakeFirestore()) {
    state = const AuthState(initializing: false);
  }
}

void main() {
  testWidgets('a signed-out user lands on the sign-up screen, with Google sign-in on it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((ref) => _SignedOutAuth())],
        child: const BookmarkedApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Bookmarked'), findsWidgets);
    expect(find.text("Let's set up your shelf"), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Already have a shelf? Log in'), findsOneWidget);
  });
}
