import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club.dart';
import '../models/club_note.dart';
import '../models/club_review.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

const _pageSize = 30;

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
  final ApiClient _api;
  final String clubId;
  ClubHistoryNotifier(this._api, this.clubId) : super(const ClubHistoryState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final json = await _api.get('/clubs/$clubId/books', query: {'limit': '$_pageSize', 'offset': '0'});
      final map = json as Map<String, dynamic>;
      final books = (map['items'] as List).map((b) => ClubBook.fromJson(b as Map<String, dynamic>)).toList();
      state = state.copyWith(books: books, loading: false, total: map['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final json = await _api.get('/clubs/$clubId/books', query: {'limit': '$_pageSize', 'offset': '${state.books.length}'});
      final map = json as Map<String, dynamic>;
      final more = (map['items'] as List).map((b) => ClubBook.fromJson(b as Map<String, dynamic>)).toList();
      state = state.copyWith(books: [...state.books, ...more], loadingMore: false, total: map['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, error: e.message);
    }
  }
}

final clubHistoryProvider = StateNotifierProvider.family<ClubHistoryNotifier, ClubHistoryState, String>((ref, clubId) {
  return ClubHistoryNotifier(ref.watch(apiClientProvider), clubId);
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
  final ApiClient _api;
  final ClubNotesArgs args;
  final String? _myId;
  ClubNotesNotifier(this._api, this.args, this._myId) : super(const ClubNotesState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final notesJson = await _api.get('/clubs/${args.clubId}/notes', query: {
        'club_book_id': args.clubBookId,
        'limit': '$_pageSize',
        'offset': '0',
      });
      int myChapter = 0;
      if (args.isCurrent) {
        final clubJson = await _api.get('/clubs/${args.clubId}');
        final club = Club.fromJson(clubJson as Map<String, dynamic>);
        final me = _myId != null ? club.memberById(_myId) : null;
        myChapter = me?.currentChapter ?? 0;
      }
      final map = notesJson as Map<String, dynamic>;
      final notes = (map['items'] as List).map((n) => ClubNote.fromJson(n as Map<String, dynamic>)).toList();
      state = state.copyWith(notes: notes, myChapter: myChapter, loading: false, total: map['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final json = await _api.get('/clubs/${args.clubId}/notes', query: {
        'club_book_id': args.clubBookId,
        'limit': '$_pageSize',
        'offset': '${state.notes.length}',
      });
      final map = json as Map<String, dynamic>;
      final more = (map['items'] as List).map((n) => ClubNote.fromJson(n as Map<String, dynamic>)).toList();
      state = state.copyWith(notes: [...state.notes, ...more], loadingMore: false, total: map['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, error: e.message);
    }
  }

  Future<bool> addNote(int chapter, String body) async {
    try {
      await _api.post('/clubs/${args.clubId}/notes', body: {'chapter': chapter, 'body': body});
      await load();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }
}

final clubNotesProvider = StateNotifierProvider.family<ClubNotesNotifier, ClubNotesState, ClubNotesArgs>((ref, args) {
  final myId = ref.watch(authProvider).user?.id;
  return ClubNotesNotifier(ref.watch(apiClientProvider), args, myId);
});

// --- Reviews -----------------------------------------------------

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
