import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club.dart';
import '../models/club_bingo.dart';
import 'auth_provider.dart';

// Mirrors the retired backend's DEFAULT_LABELS (`git show
// 99e92f1:backend/app/routers/bingo.py`) — position 12 is the fixed FREE SPACE, pre-completed and locked.
const _defaultClubBingoLabels = [
  "Read a debut author", "Book under 250 pages", "Author you've never read", "One-word title", "Read outdoors",
  "A retelling", "Book club pick", "Enemies to lovers", "A buddy read", "Published this year",
  "Recommended by a friend", "A trope you avoid", "FREE SPACE", "Finish in one sitting", "Book over 500 pages",
  "Audiobook", "Reread a favourite", "Cover you love", "Backlist title", "Translated work",
  "Series finale", "Cozy mystery", "Non-fiction pick", "Banned book", "5-star surprise",
];
const _clubBingoFreeSpacePosition = 12;

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
/// `users/{uid}` profile and, if the club has a current book, that member's
/// reading progress on it) into a [Club].
Future<Club> fetchClub(FirebaseFirestore db, String clubId, String myRole) async {
  final clubRef = db.collection('clubs').doc(clubId);
  final clubDoc = await clubRef.get();
  final data = clubDoc.data();
  if (data == null) throw StateError('Club not found');

  final currentBookSnap = await clubRef.collection('books').where('isCurrent', isEqualTo: true).limit(1).get();
  final currentBookDoc = currentBookSnap.docs.isEmpty ? null : currentBookSnap.docs.first;
  final currentBook = currentBookDoc != null ? ClubBook.fromFirestore(currentBookDoc) : null;

  var progressByUser = const <String, Map<String, dynamic>>{};
  if (currentBookDoc != null) {
    final progressSnap = await currentBookDoc.reference.collection('progress').get();
    progressByUser = {for (final p in progressSnap.docs) p.id: p.data()};
  }

  final membershipsSnap = await clubRef.collection('memberships').get();
  final members = <ClubMember>[];
  for (final m in membershipsSnap.docs) {
    final md = m.data();
    final profile = (await db.collection('users').doc(m.id).get()).data();
    final progress = progressByUser[m.id];
    members.add(ClubMember(
      userId: m.id,
      name: profile?['name'] as String? ?? 'Reader',
      avatarUrl: profile?['avatarUrl'] as String?,
      role: md['role'] as String,
      status: md['status'] as String,
      currentChapter: progress?['currentChapter'] as int?,
      finished: progress?['finished'] as bool?,
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
    currentBook: currentBook,
  );
}

/// Reads the club bingo template (creating the 25-label default if it
/// doesn't exist yet) and the signed-in member's own card (creating it —
/// with the free space pre-completed and locked — from the template if
/// this is their first visit), plus a leaderboard across every active
/// member who already has a card. Mirrors `_get_or_create_member_bingo`.
Future<ClubBingo> fetchOrCreateClubBingo(FirebaseFirestore db, String clubId, String uid) async {
  final clubRef = db.collection('clubs').doc(clubId);
  final templateRef = clubRef.collection('bingoTemplate');
  final memberBingoRef = clubRef.collection('memberBingo');

  var templateSnap = await templateRef.get();
  List<String> templateLabels;
  if (templateSnap.docs.isEmpty) {
    final labels = List<String>.from(_defaultClubBingoLabels);
    labels[_clubBingoFreeSpacePosition] = 'FREE SPACE';
    final batch = db.batch();
    for (var position = 0; position < labels.length; position++) {
      batch.set(templateRef.doc('$position'), {'label': labels[position]});
    }
    await batch.commit();
    templateLabels = labels;
  } else {
    templateLabels = List<String>.filled(templateSnap.docs.length, '');
    for (final doc in templateSnap.docs) {
      templateLabels[int.parse(doc.id)] = doc.data()['label'] as String? ?? '';
    }
  }

  final myCardRef = memberBingoRef.doc(uid);
  var mySquaresSnap = await myCardRef.collection('squares').get();
  if (mySquaresSnap.docs.isEmpty) {
    final batch = db.batch();
    batch.set(myCardRef, {'wonAt': null}, SetOptions(merge: true));
    for (var position = 0; position < templateLabels.length; position++) {
      final isFree = position == _clubBingoFreeSpacePosition;
      batch.set(myCardRef.collection('squares').doc('$position'), {
        'position': position,
        'label': templateLabels[position],
        'completed': isFree,
        'locked': isFree,
      });
    }
    await batch.commit();
    mySquaresSnap = await myCardRef.collection('squares').get();
  }
  final mySquares = mySquaresSnap.docs.map(ClubBingoSquare.fromFirestore).toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  final activeMembers = await clubRef.collection('memberships').where('status', isEqualTo: 'active').get();
  final leaderboard = <ClubBingoLeaderboardEntry>[];
  for (final membership in activeMembers.docs) {
    final cardSnap = await memberBingoRef.doc(membership.id).get();
    if (!cardSnap.exists) continue;
    final squaresSnap = await memberBingoRef.doc(membership.id).collection('squares').get();
    if (squaresSnap.docs.isEmpty) continue;
    final profile = (await db.collection('users').doc(membership.id).get()).data();
    leaderboard.add(ClubBingoLeaderboardEntry(
      userId: membership.id,
      name: profile?['name'] as String? ?? 'Reader',
      completedCount: squaresSnap.docs.where((d) => d.data()['completed'] == true).length,
      totalCount: squaresSnap.docs.length,
      wonAt: (cardSnap.data()?['wonAt'] as Timestamp?)?.toDate(),
    ));
  }
  leaderboard.sort((a, b) {
    final byCompleted = b.completedCount.compareTo(a.completedCount);
    if (byCompleted != 0) return byCompleted;
    return (a.wonAt ?? DateTime(9999)).compareTo(b.wonAt ?? DateTime(9999));
  });

  return ClubBingo(squares: mySquares, leaderboard: leaderboard);
}

class ClubsNotifier extends StateNotifier<ClubsState> {
  final FirebaseFirestore _db;
  final String? _uid;
  ClubsNotifier(this._db, this._uid) : super(const ClubsState());

  CollectionReference<Map<String, dynamic>> _memberships(String clubId) =>
      _db.collection('clubs').doc(clubId).collection('memberships');

  CollectionReference<Map<String, dynamic>> _books(String clubId) =>
      _db.collection('clubs').doc(clubId).collection('books');

  Future<DocumentSnapshot<Map<String, dynamic>>?> _currentBookDoc(String clubId) async {
    final snap = await _books(clubId).where('isCurrent', isEqualTo: true).limit(1).get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }

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

  Future<bool> updateClub(String clubId, {String? name, String? description, String? imageUrl}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
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

  /// Picks a club's current book, retiring any previous current book and
  /// giving every active member a fresh (chapter 0, unfinished) progress
  /// doc for it — mirrors `set_current_book` from the old backend.
  Future<bool> setCurrentBook(
    String clubId, {
    required String title,
    required String author,
    int? totalChapters,
    String? coverUrl,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final priorCurrent = await _currentBookDoc(clubId);
      final activeMembers = await _memberships(clubId).where('status', isEqualTo: 'active').get();

      final batch = _db.batch();
      if (priorCurrent != null) {
        batch.update(priorCurrent.reference, {'isCurrent': false});
      }
      final newBookRef = _books(clubId).doc();
      batch.set(newBookRef, {
        'title': title,
        'author': author,
        'totalChapters': totalChapters,
        'coverColor': '#3F5D4E',
        'coverUrl': coverUrl,
        'isCurrent': true,
        'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'pickedAt': FieldValue.serverTimestamp(),
      });
      for (final membership in activeMembers.docs) {
        batch.set(newBookRef.collection('progress').doc(membership.id), {
          'currentChapter': 0,
          'finished': false,
          'finishedAt': null,
        });
      }
      await batch.commit();
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> updateCurrentBookDates(String clubId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final book = await _currentBookDoc(clubId);
      if (book == null) {
        state = state.copyWith(error: "This club hasn't picked a book yet");
        return false;
      }
      await book.reference.update({
        'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
      });
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  /// Updates the signed-in member's own progress on the club's current book,
  /// creating the progress doc on first write — mirrors `update_progress`.
  Future<bool> updateMyProgress(String clubId, {int? currentChapter, bool? finished}) async {
    if (_uid == null) return false;
    try {
      final book = await _currentBookDoc(clubId);
      if (book == null) {
        state = state.copyWith(error: "This club hasn't picked a book yet");
        return false;
      }
      final updates = <String, dynamic>{};
      if (currentChapter != null) updates['currentChapter'] = currentChapter;
      if (finished != null) {
        updates['finished'] = finished;
        updates['finishedAt'] = finished ? FieldValue.serverTimestamp() : null;
      }
      if (updates.isEmpty) return true;
      await book.reference.collection('progress').doc(_uid).set(updates, SetOptions(merge: true));
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  /// Toggles one of the signed-in member's own bingo squares, then
  /// recomputes their `wonAt` — mirrors `toggle_bingo_square`. Win
  /// detection is deliberately client-trusted, same as personal bingo: see
  /// the ADR's note on game-integrity logic not being worth a Cloud
  /// Function for a small club of trusted people.
  Future<bool> toggleBingoSquare(String clubId, String position, bool currentlyCompleted) async {
    if (_uid == null) return false;
    try {
      final cardRef = _db.collection('clubs').doc(clubId).collection('memberBingo').doc(_uid);
      final squareRef = cardRef.collection('squares').doc(position);
      final data = (await squareRef.get()).data();
      if (data == null) {
        state = state.copyWith(error: 'Bingo square not found');
        return false;
      }
      if (data['locked'] == true) {
        state = state.copyWith(error: "This square can't be edited");
        return false;
      }
      await squareRef.update({'completed': !currentlyCompleted});

      final squares = await cardRef.collection('squares').get();
      final allCompleted = squares.docs.every((d) => d.data()['completed'] == true);
      if (allCompleted) {
        final card = await cardRef.get();
        if (card.data()?['wonAt'] == null) {
          await cardRef.set({'wonAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      } else {
        await cardRef.set({'wonAt': null}, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }

  /// Replaces the club's bingo template and resets every member's card,
  /// including the caller's own — mirrors `set_bingo_template`. The next
  /// read via [fetchOrCreateClubBingo] lazily recreates the caller's card
  /// from the new template.
  Future<bool> setBingoTemplate(String clubId, List<String> labels) async {
    try {
      final fixedLabels = List<String>.from(labels);
      fixedLabels[_clubBingoFreeSpacePosition] = 'FREE SPACE';

      final clubRef = _db.collection('clubs').doc(clubId);
      final templateRef = clubRef.collection('bingoTemplate');
      final memberBingoRef = clubRef.collection('memberBingo');

      final existingTemplate = await templateRef.get();
      final templateBatch = _db.batch();
      for (final doc in existingTemplate.docs) {
        templateBatch.delete(doc.reference);
      }
      for (var position = 0; position < fixedLabels.length; position++) {
        templateBatch.set(templateRef.doc('$position'), {'label': fixedLabels[position]});
      }
      await templateBatch.commit();

      final existingMemberCards = await memberBingoRef.get();
      for (final cardDoc in existingMemberCards.docs) {
        final squares = await cardDoc.reference.collection('squares').get();
        final cardBatch = _db.batch();
        for (final square in squares.docs) {
          cardBatch.delete(square.reference);
        }
        cardBatch.delete(cardDoc.reference);
        await cardBatch.commit();
      }
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
