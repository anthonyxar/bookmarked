import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.dart';
import '../utils/image_validation.dart';

final firebaseAuthProvider = Provider<fb_auth.FirebaseAuth>((ref) => fb_auth.FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

class AuthState {
  final AppUser? user;
  final bool loading;
  final bool initializing;
  final String? error;

  const AuthState({this.user, this.loading = false, this.initializing = true, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({AppUser? user, bool? loading, bool? initializing, String? error, bool clearError = false, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      initializing: initializing ?? this.initializing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final fb_auth.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  // Lazy: constructing GoogleSignIn eagerly crashes on web without a
  // configured client ID, and there's no reason to pay for it on native
  // platforms until sign-in is actually attempted.
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn => _googleSignInInstance ??= GoogleSignIn();

  StreamSubscription<fb_auth.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<String>? _tokenRefreshSub;

  // Guards against re-registering on every live profile snapshot (the
  // listener re-fires on any field change, including our own token write) —
  // and against running before the profile doc exists, which would race
  // register()'s/signInWithGoogle's own (non-merge) writes to it.
  String? _fcmRegisteredForUid;

  AuthNotifier(this._auth, this._db) : super(const AuthState()) {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(fb_auth.User? user) {
    _profileSub?.cancel();
    if (user == null) {
      _tokenRefreshSub?.cancel();
      _fcmRegisteredForUid = null;
      state = const AuthState(initializing: false);
      return;
    }
    _profileSub = _db.collection('users').doc(user.uid).snapshots().listen((doc) {
      if (!doc.exists) {
        // Signed in but no profile yet (mid-register, or an earlier profile
        // write failed) — don't leave the auth gate spinning forever.
        state = state.copyWith(initializing: false);
        return;
      }
      state = state.copyWith(user: AppUser.fromFirestore(doc), initializing: false);
      if (_fcmRegisteredForUid != user.uid) {
        _fcmRegisteredForUid = user.uid;
        _registerFcmToken(user.uid);
      }
    }, onError: (Object e) {
      state = state.copyWith(initializing: false, error: _describeError(e));
    });
  }

  /// Requests notification permission and stores this device's FCM token on
  /// the user's profile (an array, since one account may have several
  /// devices) — the invite/new-club-book Cloud Function triggers (#18) send
  /// to every token there. Silently no-ops on denial/failure: push is a
  /// nice-to-have, never a sign-in blocker.
  Future<void> _registerFcmToken(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
        });
      });
    } catch (_) {
      // Notification permission/token registration failures shouldn't block sign-in.
    }
  }

  String _friendlyError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'invalid-email':
        return 'That email address looks invalid';
      default:
        return e.message ?? 'Something went wrong';
    }
  }

  /// Message for anything that isn't a FirebaseAuthException — Firestore
  /// failures (rules not deployed, database missing, offline) and Google
  /// sign-in PlatformExceptions — so a failed step surfaces an error instead of
  /// leaving `loading` stuck on.
  String _describeError(Object e) {
    if (e is FirebaseException) return '${e.message ?? 'Something went wrong'} (${e.code})';
    if (e is PlatformException) return '${e.message ?? 'Sign-in failed'} (${e.code})';
    return 'Something went wrong';
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required int readingGoal,
    required List<String> genres,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(name);
      await _db.collection('users').doc(uid).set({
        'name': name,
        'avatarUrl': null,
        'readingGoal': readingGoal,
        'genres': genres,
        'createdAt': FieldValue.serverTimestamp(),
      });
      state = state.copyWith(loading: false);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: _describeError(e));
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      state = state.copyWith(loading: false);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: _describeError(e));
      return false;
    }
  }

  /// Signs in (or registers, on first use) with Google. Returns false without
  /// setting an error if the user simply cancelled the picker.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(loading: false);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;
      final doc = _db.collection('users').doc(uid);
      if (!(await doc.get()).exists) {
        await doc.set({
          'name': userCredential.user!.displayName ?? 'Reader',
          'avatarUrl': userCredential.user!.photoURL,
          'readingGoal': 40,
          'genres': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      state = state.copyWith(loading: false);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: _describeError(e));
      return false;
    }
  }

  Future<void> updateProfile({String? name, int? readingGoal, List<String>? genres}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (readingGoal != null) updates['readingGoal'] = readingGoal;
    if (genres != null) updates['genres'] = genres;
    if (updates.isEmpty) return;
    await _db.collection('users').doc(uid).update(updates);
  }

  Future<bool> uploadAvatar({required Uint8List bytes, required String filename}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final validationError = imageValidationError(filename, bytes.length);
    if (validationError != null) {
      state = state.copyWith(error: validationError);
      return false;
    }
    try {
      final ref = FirebaseStorage.instance.ref('avatars/$uid');
      await ref.putData(bytes, SettableMetadata(contentType: contentTypeForFilename(filename)));
      final url = await ref.getDownloadURL();
      await _db.collection('users').doc(uid).update({'avatarUrl': url});
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Could not upload that image');
      return false;
    }
  }

  Future<void> logout() async {
    // Only touch GoogleSignIn if this session actually constructed one —
    // avoids the lazy getter creating it (and, on web, crashing without a
    // configured client ID) on every logout regardless of sign-in method.
    if (_googleSignInInstance != null && await _googleSignInInstance!.isSignedIn()) {
      await _googleSignInInstance!.signOut();
    }
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider));
});
