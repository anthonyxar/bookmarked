import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club.dart';
import 'auth_provider.dart';

class ClubsState {
  final List<Club> clubs;
  final List<ClubInvite> invites;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int total;

  const ClubsState({
    this.clubs = const [],
    this.invites = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.total = 0,
  });

  bool get hasMore => false;

  ClubsState copyWith({
    List<Club>? clubs,
    List<ClubInvite>? invites,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? total,
  }) {
    return ClubsState(
      clubs: clubs ?? this.clubs,
      invites: invites ?? this.invites,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      total: total ?? this.total,
    );
  }
}

String _friendlyError(Object e) {
  if (e is FirebaseFunctionsException) return e.message ?? 'Something went wrong';
  if (e is FirebaseException) return e.message ?? 'Something went wrong';
  return '$e';
}

/// Reads a club doc plus its memberships (each joined against the member's
/// `users/{uid}` profile) into a [Club]. `currentBook` stays null until the
/// club-book/progress domain (issue #14) is migrated.
Future<Club> fetchClub(FirebaseFirestore db, String clubId, String myRole) async {
  final clubRef = db.collection('clubs').doc(clubId);
  final clubDoc = await clubRef.get();
  final data = clubDoc.data();
  if (data == null) throw StateError('Club not found');

  final membershipsSnap = await clubRef.collection('memberships').get();
  final members = <ClubMember>[];
  for (final m in membershipsSnap.docs) {
    final md = m.data();
    final profile = (await db.collection('users').doc(m.id).get()).data();
    members.add(ClubMember(
      userId: m.id,
      name: profile?['name'] as String? ?? 'Reader',
      avatarUrl: profile?['avatarUrl'] as String?,
      role: md['role'] as String,
      status: md['status'] as String,
    ));
  }

  return Club(
    id: clubDoc.id,
    name: data['name'] as String,
    description: data['description'] as String?,
    imageUrl: data['imageUrl'] as String?,
    ownerId: data['ownerId'] as String,
    myRole: myRole,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    members: members,
  );
}

class ClubsNotifier extends StateNotifier<ClubsState> {
  final FirebaseFirestore _db;
  final String? _uid;
  ClubsNotifier(this._db, this._uid) : super(const ClubsState());

  CollectionReference<Map<String, dynamic>> _memberships(String clubId) =>
      _db.collection('clubs').doc(clubId).collection('memberships');

  Future<void> load() async {
    if (_uid == null) {
      state = state.copyWith(loading: false);
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final mine = await _db.collectionGroup('memberships').where('userId', isEqualTo: _uid).get();

      final clubs = <Club>[];
      final invites = <ClubInvite>[];
      for (final doc in mine.docs) {
        final data = doc.data();
        final clubRef = doc.reference.parent.parent!;
        final status = data['status'] as String;
        if (status == 'active') {
          clubs.add(await fetchClub(_db, clubRef.id, data['role'] as String));
        } else if (status == 'invited') {
          final clubData = (await clubRef.get()).data();
          if (clubData == null) continue;
          var inviterName = 'Someone';
          final invitedById = data['invitedById'] as String?;
          if (invitedById != null) {
            final inviter = (await _db.collection('users').doc(invitedById).get()).data();
            inviterName = inviter?['name'] as String? ?? 'Someone';
          }
          invites.add(ClubInvite(
            clubId: clubRef.id,
            clubName: clubData['name'] as String,
            invitedByName: inviterName,
            invitedAt: (data['invitedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        }
      }
      clubs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(clubs: clubs, invites: invites, loading: false, total: clubs.length);
    } catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
    }
  }

  /// No-op: the club list isn't paginated (personal-scale club counts).
  /// Kept so existing scroll-to-load-more call sites don't need to change.
  Future<void> loadMore() async {}

  Future<Club?> create(String name, String? description) async {
    if (_uid == null) return null;
    try {
      final clubRef = await _db.collection('clubs').add({
        'name': name,
        'description': description,
        'imageUrl': null,
        'ownerId': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await clubRef.collection('memberships').doc(_uid).set({
        'userId': _uid,
        'role': 'owner',
        'status': 'active',
        'invitedById': null,
        'invitedAt': FieldValue.serverTimestamp(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
      final club = await fetchClub(_db, clubRef.id, 'owner');
      await load();
      return club;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return null;
    }
  }

  Future<bool> respondToInvite(String clubId, bool accept) async {
    if (_uid == null) return false;
    try {
      if (accept) {
        await _memberships(clubId).doc(_uid).update({'status': 'active', 'joinedAt': FieldValue.serverTimestamp()});
      } else {
        await _memberships(clubId).doc(_uid).update({'status': 'declined'});
      }
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> leaveClub(String clubId) async {
    if (_uid == null) return false;
    try {
      final ref = _memberships(clubId).doc(_uid);
      final data = (await ref.get()).data();
      if (data?['role'] == 'owner') {
        state = state.copyWith(error: "The owner can't leave the club — delete it or hand off ownership first");
        return false;
      }
      await ref.update({'status': 'removed'});
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> deleteClub(String clubId) async {
    if (_uid == null) return false;
    try {
      final clubRef = _db.collection('clubs').doc(clubId);
      final data = (await clubRef.get()).data();
      if (data?['ownerId'] != _uid) {
        state = state.copyWith(error: 'Only the club owner can delete this club');
        return false;
      }
      // Deletes just the club doc — its subcollections (memberships, books,
      // etc.) are cleaned up by the recursive-delete Cloud Function (#17),
      // since Firestore doesn't cascade deletes on its own.
      await clubRef.delete();
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> transferOwnership(String clubId, String newOwnerId) async {
    if (_uid == null) return false;
    try {
      final clubRef = _db.collection('clubs').doc(clubId);
      final newOwnerData = (await _memberships(clubId).doc(newOwnerId).get()).data();
      if (newOwnerData == null || newOwnerData['status'] != 'active') {
        state = state.copyWith(error: "That person isn't an active member of this club");
        return false;
      }
      final batch = _db.batch();
      batch.update(clubRef, {'ownerId': newOwnerId});
      batch.update(_memberships(clubId).doc(newOwnerId), {'role': 'owner'});
      batch.update(_memberships(clubId).doc(_uid), {'role': 'admin'});
      await batch.commit();
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> updateClub(String clubId, {String? name, String? description}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (updates.isEmpty) return true;
      await _db.collection('clubs').doc(clubId).update(updates);
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  /// Looks up the invitee by email via a Cloud Function (Firebase Auth's
  /// email index is admin-only — see issue #23) then writes/updates their
  /// membership doc directly.
  Future<bool> inviteMember(String clubId, String email) async {
    if (_uid == null) return false;
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('lookupUserByEmail').call({'email': email});
      final inviteeUid = result.data['uid'] as String;

      final ref = _memberships(clubId).doc(inviteeUid);
      final existing = (await ref.get()).data();
      if (existing != null && existing['status'] == 'active') {
        state = state.copyWith(error: 'That person is already in the club');
        return false;
      }
      await ref.set({
        'userId': inviteeUid,
        'role': existing?['role'] ?? 'member',
        'status': 'invited',
        'invitedById': _uid,
        'invitedAt': FieldValue.serverTimestamp(),
        'joinedAt': existing?['joinedAt'],
      });
      return true;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(error: e.code == 'not-found' ? 'No Bookmarked user found with that email' : (e.message ?? 'Something went wrong'));
      return false;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> updateMemberRole(String clubId, String userId, String role) async {
    try {
      await _memberships(clubId).doc(userId).update({'role': role});
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> removeMember(String clubId, String userId) async {
    try {
      await _memberships(clubId).doc(userId).update({'status': 'removed'});
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }
}

final clubsProvider = StateNotifierProvider<ClubsNotifier, ClubsState>((ref) {
  return ClubsNotifier(ref.watch(firestoreProvider), ref.watch(authProvider).user?.id);
});
