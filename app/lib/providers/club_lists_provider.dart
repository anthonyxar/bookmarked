import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club.dart';
import '../models/club_note.dart';
import '../models/club_review.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

const _pageSize = 30;

String _friendlyError(Object e) {
  if (e is FirebaseException) return e.message ?? 'Something went wrong';
  return '$e';
}

// --- Club book history -----------------------------------------------------

class ClubHistoryState {
  final List<ClubBook> books;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int total;

  const ClubHistoryState({
    this.books = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.total = 0,
  });

  bool get hasMore => books.length < total;

  ClubHistoryState copyWith({
    List<ClubBook>? books,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? total,
  }) {
    return ClubHistoryState(
      books: books ?? this.books,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      total: total ?? this.total,
    );
  }
}

class ClubHistoryNotifier extends StateNotifier<ClubHistoryState> {
  final FirebaseFirestore _db;
  final String clubId;
  ClubHistoryNotifier(this._db, this.clubId) : super(const ClubHistoryState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final snap =
          await _db.collection('clubs').doc(clubId).collection('books').orderBy('pickedAt', descending: true).get();
      final books = snap.docs.map(ClubBook.fromFirestore).toList();
      state = state.copyWith(books: books, loading: false, total: books.length);
    } catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
    }
  }

  /// No-op: club book history isn't paginated (personal-scale club counts).
  /// Kept so the existing scroll-to-load-more call site doesn't need to change.
  Future<void> loadMore() async {}
}

final clubHistoryProvider = StateNotifierProvider.family<ClubHistoryNotifier, ClubHistoryState, String>((ref, clubId) {
  return ClubHistoryNotifier(ref.watch(firestoreProvider), clubId);
});

// --- Chapter notes -----------------------------------------------------

typedef ClubNotesArgs = ({String clubId, String clubBookId, bool isCurrent});

class ClubNotesState {
  final List<ClubNote> notes;
  final int myChapter;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int total;

  const ClubNotesState({
    this.notes = const [],
    this.myChapter = 0,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.total = 0,
  });

  bool get hasMore => notes.length < total;

  ClubNotesState copyWith({
    List<ClubNote>? notes,
    int? myChapter,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? total,
  }) {
    return ClubNotesState(
      notes: notes ?? this.notes,
      myChapter: myChapter ?? this.myChapter,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      total: total ?? this.total,
    );
  }
}

class ClubNotesNotifier extends StateNotifier<ClubNotesState> {
  final FirebaseFirestore _db;
  final ClubNotesArgs args;
  final String? _myId;
  ClubNotesNotifier(this._db, this.args, this._myId) : super(const ClubNotesState()) {
    load();
  }

  DocumentReference<Map<String, dynamic>> get _bookRef =>
      _db.collection('clubs').doc(args.clubId).collection('books').doc(args.clubBookId);

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      var myChapter = 0;
      if (_myId != null) {
        final progress = await _bookRef.collection('progress').doc(_myId).get();
        myChapter = progress.data()?['currentChapter'] as int? ?? 0;
      }

      // Spoiler visibility (a note's chapter vs. the viewer's own progress)
      // is application logic, not a Firestore query — fetch this book's
      // notes and filter/sort client-side, same as the old backend did.
      final notesSnap = await _bookRef.collection('notes').get();
      final authorNames = <String, String>{};
      final notes = <ClubNote>[];
      for (final doc in notesSnap.docs) {
        final data = doc.data();
        final chapter = data['chapter'] as int;
        final userId = data['userId'] as String;
        if (userId != _myId && chapter > myChapter) continue;
        final authorName =
            authorNames[userId] ??= (await _db.collection('users').doc(userId).get()).data()?['name'] as String? ?? 'Reader';
        notes.add(ClubNote.fromFirestore(doc, authorName: authorName));
      }
      notes.sort((a, b) {
        final byChapter = a.chapter.compareTo(b.chapter);
        return byChapter != 0 ? byChapter : a.createdAt.compareTo(b.createdAt);
      });

      state = state.copyWith(notes: notes, myChapter: myChapter, loading: false, total: notes.length);
    } catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
    }
  }

  /// No-op: chapter notes aren't paginated (personal-scale club counts).
  /// Kept so the existing scroll-to-load-more call site doesn't need to change.
  Future<void> loadMore() async {}

  Future<bool> addNote(int chapter, String body) async {
    if (_myId == null) return false;
    if (chapter > state.myChapter) {
      state = state.copyWith(error: "You can't leave a note for a chapter you haven't reached yet");
      return false;
    }
    try {
      await _bookRef.collection('notes').add({
        'chapter': chapter,
        'body': body,
        'userId': _myId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }
}

final clubNotesProvider = StateNotifierProvider.family<ClubNotesNotifier, ClubNotesState, ClubNotesArgs>((ref, args) {
  final myId = ref.watch(authProvider).user?.id;
  return ClubNotesNotifier(ref.watch(firestoreProvider), args, myId);
});

// --- Reviews -----------------------------------------------------

// NOT migrated by issue #14: `list_reviews` reads every active member's
// personal `books` doc (title/author-matched) to build the cross-member
// review list, but issue #9's Firestore rules only let a user read their
// own `users/{uid}/books/**`. A pure client migration would need those
// rules loosened (a real privacy regression) — this almost certainly needs
// a Cloud Function instead, which is outside #14's "plain CRUD" scope.
// Left on the REST backend until that's designed (flagged in #14's closing
// comment; file a follow-up issue before deleting `backend/` in #20).
typedef ClubReviewsArgs = ({String clubId, String clubBookId});

class ClubReviewsState {
  final List<ClubReviewEntry> reviews;
  final bool loading;
  final bool loadingMore;
  final bool revealed;
  final String? error;
  final int total;

  const ClubReviewsState({
    this.reviews = const [],
    this.loading = false,
    this.loadingMore = false,
    this.revealed = false,
    this.error,
    this.total = 0,
  });

  bool get hasMore => reviews.length < total;

  ClubReviewsState copyWith({
    List<ClubReviewEntry>? reviews,
    bool? loading,
    bool? loadingMore,
    bool? revealed,
    String? error,
    bool clearError = false,
    int? total,
  }) {
    return ClubReviewsState(
      reviews: reviews ?? this.reviews,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      revealed: revealed ?? this.revealed,
      error: clearError ? null : (error ?? this.error),
      total: total ?? this.total,
    );
  }
}

class ClubReviewsNotifier extends StateNotifier<ClubReviewsState> {
  final ApiClient _api;
  final ClubReviewsArgs args;
  ClubReviewsNotifier(this._api, this.args) : super(const ClubReviewsState()) {
    load();
  }

  Future<void> load({bool override = false}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final json = await _api.get('/clubs/${args.clubId}/reviews', query: {
        'override': override.toString(),
        'club_book_id': args.clubBookId,
        'limit': '$_pageSize',
        'offset': '0',
      });
      final map = json as Map<String, dynamic>;
      final reviews = (map['items'] as List).map((r) => ClubReviewEntry.fromJson(r as Map<String, dynamic>)).toList();
      state = state.copyWith(reviews: reviews, revealed: override, loading: false, total: map['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final json = await _api.get('/clubs/${args.clubId}/reviews', query: {
        'override': state.revealed.toString(),
        'club_book_id': args.clubBookId,
        'limit': '$_pageSize',
        'offset': '${state.reviews.length}',
      });
      final map = json as Map<String, dynamic>;
      final more = (map['items'] as List).map((r) => ClubReviewEntry.fromJson(r as Map<String, dynamic>)).toList();
      state = state.copyWith(reviews: [...state.reviews, ...more], loadingMore: false, total: map['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, error: e.message);
    }
  }
}

final clubReviewsProvider = StateNotifierProvider.family<ClubReviewsNotifier, ClubReviewsState, ClubReviewsArgs>((ref, args) {
  return ClubReviewsNotifier(ref.watch(apiClientProvider), args);
});
