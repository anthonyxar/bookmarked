import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../models/bracket.dart';
import 'auth_provider.dart';
import 'books_provider.dart';
import 'year_provider.dart';

// Wildcard round pairs the 8 non-bye months (in month order); the 4
// highest-rated months skip straight to the quarterfinals. Mirrors the
// retired backend's _compute_bracket (`git show
// 99e92f1:backend/app/routers/bracket.py`).
const _byeCount = 4;

typedef _Entry = MapEntry<int, Book>; // month -> book

class BracketState {
  final BracketData? bracket;
  final bool loading;
  final String? error;
  final int selectedYear;

  const BracketState({this.bracket, this.loading = false, this.error, required this.selectedYear});

  BracketState copyWith({BracketData? bracket, bool? loading, String? error, int? selectedYear, bool clearError = false}) =>
      BracketState(
        bracket: bracket ?? this.bracket,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        selectedYear: selectedYear ?? this.selectedYear,
      );
}

class BracketNotifier extends StateNotifier<BracketState> {
  final FirebaseFirestore _db;
  final String? _uid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pickSub;
  List<Book> _books = const [];
  Map<int, String> _favorites = const {};
  Map<String, String> _picks = const {};

  BracketNotifier(Ref ref, this._db, this._uid, int initialYear) : super(BracketState(selectedYear: initialYear)) {
    ref.listen<AsyncValue<List<Book>>>(userBooksProvider, (previous, next) {
      next.whenData((books) {
        _books = books;
        _recompute();
      });
    }, fireImmediately: true);
    _subscribeYear(initialYear);
  }

  String _friendlyError(Object e) => e is FirebaseException ? (e.message ?? 'Something went wrong') : '$e';

  CollectionReference<Map<String, dynamic>> _favoritesCollection(int year) =>
      _db.collection('users').doc(_uid).collection('monthlyFavorites').doc('$year').collection('months');

  CollectionReference<Map<String, dynamic>> _picksCollection(int year) =>
      _db.collection('users').doc(_uid).collection('bracketPicks').doc('$year').collection('matches');

  void _subscribeYear(int year) {
    _favSub?.cancel();
    _pickSub?.cancel();
    if (_uid == null) return;
    _favSub = _favoritesCollection(year).snapshots().listen(
      (snap) {
        _favorites = {for (final d in snap.docs) (d.data()['month'] as int): d.data()['bookId'] as String};
        _recompute();
      },
      onError: (Object e) => state = state.copyWith(loading: false, error: _friendlyError(e)),
    );
    _pickSub = _picksCollection(year).snapshots().listen(
      (snap) {
        _picks = {for (final d in snap.docs) d.id: d.data()['bookId'] as String};
        _recompute();
      },
      onError: (Object e) => state = state.copyWith(loading: false, error: _friendlyError(e)),
    );
  }

  Future<void> load({int? year}) async {
    final selectedYear = year ?? state.selectedYear;
    if (selectedYear != state.selectedYear || state.bracket == null) {
      state = state.copyWith(selectedYear: selectedYear, loading: true, clearError: true);
      _favorites = const {};
      _picks = const {};
      _subscribeYear(selectedYear);
    } else {
      _recompute();
    }
  }

  BracketBook _bookBrief(Book book, int? month) => BracketBook(
        id: book.id,
        title: book.title,
        author: book.author,
        coverColor: book.coverColor,
        coverUrl: book.coverUrl,
        rating: book.rating,
        month: month,
      );

  void _recompute() {
    if (_uid == null) {
      state = state.copyWith(loading: false);
      return;
    }
    state = state.copyWith(bracket: _computeBracket(state.selectedYear), loading: false, clearError: true);
  }

  BracketData _computeBracket(int year) {
    final booksById = {for (final b in _books) b.id: b};

    final favoritesOut = <BracketFavorite>[];
    final entries = <int, _Entry>{};
    for (var month = 1; month <= 12; month++) {
      final bookId = _favorites[month];
      final book = bookId != null ? booksById[bookId] : null;
      favoritesOut.add(BracketFavorite(month: month, book: book != null ? _bookBrief(book, month) : null));
      if (book != null) entries[month] = MapEntry(month, book);
    }

    if (entries.length < 12) {
      return BracketData(year: year, monthsSet: entries.length, favorites: favoritesOut, matches: null, champion: null);
    }

    final ranked = entries.values.toList()
      ..sort((a, b) {
        final byRating = (b.value.rating ?? 0).compareTo(a.value.rating ?? 0);
        return byRating != 0 ? byRating : a.key.compareTo(b.key);
      });
    final byes = ranked.take(_byeCount).toList()..sort((a, b) => a.key.compareTo(b.key));
    final wcEntrants = ranked.skip(_byeCount).toList()..sort((a, b) => a.key.compareTo(b.key));
    final wcPairs = [for (var i = 0; i < 4; i++) (wcEntrants[i * 2], wcEntrants[i * 2 + 1])];

    final matches = <BracketMatch>[];
    _Entry? resolve(String matchId, String round, _Entry? a, _Entry? b) {
      final winnerId = _picks[matchId];
      matches.add(BracketMatch(
        id: matchId,
        round: round,
        bookA: a != null ? _bookBrief(a.value, a.key) : null,
        bookB: b != null ? _bookBrief(b.value, b.key) : null,
        winnerId: winnerId,
      ));
      if (winnerId == null) return null;
      for (final entry in [a, b]) {
        if (entry != null && entry.value.id == winnerId) return entry;
      }
      return null;
    }

    final wcWinners = [for (var i = 0; i < 4; i++) resolve('wc${i + 1}', 'wildcard', wcPairs[i].$1, wcPairs[i].$2)];
    final qfWinners = [for (var i = 0; i < 4; i++) resolve('qf${i + 1}', 'quarterfinal', byes[i], wcWinners[i])];
    final sfWinners = [
      resolve('sf1', 'semifinal', qfWinners[0], qfWinners[1]),
      resolve('sf2', 'semifinal', qfWinners[2], qfWinners[3]),
    ];
    final finalWinner = resolve('final', 'final', sfWinners[0], sfWinners[1]);

    return BracketData(
      year: year,
      monthsSet: 12,
      favorites: favoritesOut,
      matches: matches,
      champion: finalWinner != null ? _bookBrief(finalWinner.value, finalWinner.key) : null,
    );
  }

  Future<void> setFavorite(int month, String bookId) async {
    if (_uid == null) return;
    Book? book;
    for (final b in _books) {
      if (b.id == bookId) {
        book = b;
        break;
      }
    }
    if (book == null || !book.read) {
      state = state.copyWith(error: "Only a book you've read can be a monthly favourite");
      return;
    }
    try {
      await _favoritesCollection(state.selectedYear).doc('$month').set({'month': month, 'bookId': bookId});
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
    }
  }

  Future<void> clearFavorite(int month) async {
    if (_uid == null) return;
    try {
      await _favoritesCollection(state.selectedYear).doc('$month').delete();
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
    }
  }

  Future<void> setMatchWinner(String matchId, String bookId) async {
    if (_uid == null) return;
    final match = state.bracket?.matchById(matchId);
    if (match == null) {
      state = state.copyWith(error: "That match isn't available yet");
      return;
    }
    final validIds = {match.bookA?.id, match.bookB?.id}..removeWhere((id) => id == null);
    if (!validIds.contains(bookId)) {
      state = state.copyWith(error: "That book isn't one of this match's two picks");
      return;
    }
    try {
      await _picksCollection(state.selectedYear).doc(matchId).set({'matchId': matchId, 'bookId': bookId});
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
    }
  }

  @override
  void dispose() {
    _favSub?.cancel();
    _pickSub?.cancel();
    super.dispose();
  }
}

final bracketProvider = StateNotifierProvider<BracketNotifier, BracketState>((ref) {
  final notifier = BracketNotifier(ref, ref.watch(firestoreProvider), ref.watch(authProvider.select((s) => s.user?.id)), ref.read(selectedYearProvider));
  ref.listen<int>(selectedYearProvider, (previous, next) {
    if (previous != next) notifier.load(year: next);
  });
  return notifier;
});
