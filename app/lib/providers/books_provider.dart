import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import 'auth_provider.dart';

/// The signed-in user's full book list, unfiltered — shared by [booksProvider]
/// and anything else that needs to compute over all books (dashboard,
/// challenges), so there's a single underlying Firestore listener rather than
/// one per consumer.
final userBooksProvider = StreamProvider.autoDispose<List<Book>>((ref) {
  final uid = ref.watch(authProvider).user?.id;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('books')
      .snapshots()
      .map((snap) => snap.docs.map(Book.fromFirestore).toList());
});

class BooksState {
  final List<Book> books;
  final String filter;
  final String query;
  final String sort;
  final bool loading;
  final String? error;

  const BooksState({
    this.books = const [],
    this.filter = 'all',
    this.query = '',
    this.sort = 'title',
    this.loading = true,
    this.error,
  });

  BooksState copyWith({
    List<Book>? books,
    String? filter,
    String? query,
    String? sort,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return BooksState(
      books: books ?? this.books,
      filter: filter ?? this.filter,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Rounds to the nearest half star, half-up, matching the retired backend's
/// `_compute_rating` (an exact .5 tie rounds up, e.g. 2.25 -> 2.5, not 2).
double? _computeRating(int? cover, int? writing, int? plot, int? characters) {
  final values = [cover, writing, plot, characters].whereType<int>().toList();
  if (values.isEmpty) return null;
  final avg = values.reduce((a, b) => a + b) / values.length;
  return (avg * 2 + 0.5).floorToDouble() / 2;
}

Map<String, dynamic> _normalize(Map<String, dynamic> payload) =>
    payload.map((k, v) => MapEntry(k, v is DateTime ? Timestamp.fromDate(v) : v));

int Function(Book, Book) _comparatorFor(String sort) {
  int byTitle(Book a, Book b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
  int chain(int primary, Book a, Book b) => primary != 0 ? primary : byTitle(a, b);

  switch (sort) {
    case 'author':
      return (a, b) => chain(a.author.toLowerCase().compareTo(b.author.toLowerCase()), a, b);
    case 'pages':
      return (a, b) => chain((b.pages ?? -1).compareTo(a.pages ?? -1), a, b);
    case 'times_read':
      return (a, b) => chain(b.timesRead.compareTo(a.timesRead), a, b);
    case 'end_date':
      return (a, b) {
        final ad = a.endDate, bd = b.endDate;
        final primary = ad == null && bd == null
            ? 0
            : ad == null
                ? 1
                : bd == null
                    ? -1
                    : bd.compareTo(ad);
        return chain(primary, a, b);
      };
    default:
      return byTitle;
  }
}

class BooksNotifier extends StateNotifier<BooksState> {
  final Ref _ref;
  final FirebaseFirestore _db;
  final String? _uid;
  List<Book> _allBooks = const [];

  BooksNotifier(this._ref, this._db, this._uid) : super(const BooksState()) {
    _ref.listen<AsyncValue<List<Book>>>(userBooksProvider, (previous, next) {
      next.when(
        data: (books) {
          _allBooks = books;
          _recompute();
        },
        loading: () {},
        error: (e, _) => state = state.copyWith(loading: false, error: _friendlyError(e)),
      );
    }, fireImmediately: true);
  }

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection('users').doc(_uid).collection('books');

  String _friendlyError(Object e) => e is FirebaseException ? (e.message ?? 'Something went wrong') : '$e';

  /// Firestore already streams changes live — this just updates the
  /// filter/search/sort state and recomputes the visible list, no fetch.
  Future<void> load({String? filter, String? query, String? sort}) async {
    state = state.copyWith(filter: filter ?? state.filter, query: query ?? state.query, sort: sort ?? state.sort, clearError: true);
    _recompute();
  }

  /// No-op: pagination doesn't apply to a live Firestore stream. Kept so
  /// existing scroll-to-load-more call sites don't need to change.
  Future<void> loadMore() async {}

  void _recompute() {
    Iterable<Book> result = _allBooks;
    switch (state.filter) {
      case 'toBuy':
        result = result.where((b) => !b.purchased);
      case 'reading':
        result = result.where((b) => b.purchased && !b.read);
      case 'read':
        result = result.where((b) => b.read);
    }
    final q = state.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((b) =>
          b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q) || (b.series?.toLowerCase().contains(q) ?? false));
    }
    final sorted = result.toList()..sort(_comparatorFor(state.sort));
    state = state.copyWith(books: sorted, loading: false);
  }

  Future<Book?> create(Map<String, dynamic> payload) async {
    if (_uid == null) return null;
    try {
      final read = payload['read'] as bool? ?? false;
      final data = {
        ...payload,
        'timesRead': read ? 1 : 0,
        'rating': read
            ? _computeRating(
                payload['ratingCover'] as int?,
                payload['ratingWriting'] as int?,
                payload['ratingPlot'] as int?,
                payload['ratingCharacters'] as int?,
              )
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final ref = await _collection.add(_normalize(data));
      return Book.fromFirestore(await ref.get());
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return null;
    }
  }

  Future<Book?> update(String id, Map<String, dynamic> payload) async {
    if (_uid == null) return null;
    final docRef = _collection.doc(id);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final current = snap.data() ?? const <String, dynamic>{};
        final wasRead = current['read'] as bool? ?? false;
        final merged = {...current, ...payload};
        final nowRead = merged['read'] as bool? ?? false;

        final updates = Map<String, dynamic>.from(payload);
        if (nowRead && !wasRead && !payload.containsKey('timesRead')) {
          updates['timesRead'] = (current['timesRead'] as int? ?? 0) + 1;
        }
        updates['rating'] = nowRead
            ? _computeRating(
                merged['ratingCover'] as int?,
                merged['ratingWriting'] as int?,
                merged['ratingPlot'] as int?,
                merged['ratingCharacters'] as int?,
              )
            : null;
        updates['updatedAt'] = FieldValue.serverTimestamp();
        tx.update(docRef, _normalize(updates));
      });
      return Book.fromFirestore(await docRef.get());
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return null;
    }
  }

  Future<Book?> toggleFlag(String id, String field, bool value) => update(id, {field: value});

  Future<bool> delete(String id) async {
    if (_uid == null) return false;
    try {
      await _collection.doc(id).delete();
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    }
  }
}

final booksProvider = StateNotifierProvider.autoDispose<BooksNotifier, BooksState>((ref) {
  return BooksNotifier(ref, ref.watch(firestoreProvider), ref.watch(authProvider).user?.id);
});
