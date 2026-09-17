import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bingo.dart';
import 'auth_provider.dart';
import 'year_provider.dart';

// Mirrors the retired backend's DEFAULT_LABELS (backend/app/routers/bingo.py)
// — position 12 is the fixed FREE SPACE, pre-completed and locked.
const _defaultLabels = [
  "Read a debut author", "Book under 250 pages", "Author you've never read", "One-word title", "Read outdoors",
  "A retelling", "Book club pick", "Enemies to lovers", "A buddy read", "Published this year",
  "Recommended by a friend", "A trope you avoid", "FREE SPACE", "Finish in one sitting", "Book over 500 pages",
  "Audiobook", "Reread a favourite", "Cover you love", "Backlist title", "Translated work",
  "Series finale", "Cozy mystery", "Non-fiction pick", "Banned book", "5-star surprise",
];

class BingoState {
  final BingoCard? card;
  final bool loading;
  final bool editMode;
  final String? error;
  final int selectedYear;
  final List<int> availableYears;

  const BingoState({
    this.card,
    this.loading = false,
    this.editMode = false,
    this.error,
    required this.selectedYear,
    this.availableYears = const [],
  });

  BingoState copyWith({
    BingoCard? card,
    bool? loading,
    bool? editMode,
    String? error,
    int? selectedYear,
    List<int>? availableYears,
    bool clearError = false,
    bool clearCard = false,
  }) =>
      BingoState(
        card: clearCard ? null : (card ?? this.card),
        loading: loading ?? this.loading,
        editMode: editMode ?? this.editMode,
        error: clearError ? null : (error ?? this.error),
        selectedYear: selectedYear ?? this.selectedYear,
        availableYears: availableYears ?? this.availableYears,
      );
}

class BingoNotifier extends StateNotifier<BingoState> {
  final FirebaseFirestore _db;
  final String? _uid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _squaresSub;

  BingoNotifier(this._db, this._uid, int initialYear) : super(BingoState(selectedYear: initialYear));

  CollectionReference<Map<String, dynamic>> get _cardsCollection =>
      _db.collection('users').doc(_uid).collection('bingoCards');

  String _friendlyError(Object e) => e is FirebaseException ? (e.message ?? 'Something went wrong') : '$e';

  Future<List<int>> _fetchAvailableYears() async {
    final currentYear = DateTime.now().year;
    if (_uid == null) return [currentYear];
    final snap = await _cardsCollection.get();
    final years = snap.docs.map((d) => int.parse(d.id)).toSet()..add(currentYear);
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  Future<void> _createDefaultCard(int year) async {
    final cardDoc = _cardsCollection.doc('$year');
    final batch = _db.batch();
    batch.set(cardDoc, {'year': year, 'createdAt': FieldValue.serverTimestamp()});
    for (var position = 0; position < _defaultLabels.length; position++) {
      final isFree = position == 12;
      batch.set(cardDoc.collection('squares').doc('$position'), {
        'position': position,
        'label': _defaultLabels[position],
        'completed': isFree,
        'locked': isFree,
      });
    }
    await batch.commit();
  }

  Future<void> load({int? year}) async {
    final selectedYear = year ?? state.selectedYear;
    await _squaresSub?.cancel();
    state = state.copyWith(loading: true, clearError: true, clearCard: true, selectedYear: selectedYear, editMode: false);

    if (_uid == null) {
      state = state.copyWith(loading: false);
      return;
    }

    try {
      final availableYears = await _fetchAvailableYears();
      final cardDoc = _cardsCollection.doc('$selectedYear');
      final exists = (await cardDoc.get()).exists;

      if (!exists) {
        if (selectedYear == DateTime.now().year) {
          await _createDefaultCard(selectedYear);
        } else {
          state = state.copyWith(loading: false, error: 'No bingo card for $selectedYear.', availableYears: availableYears);
          return;
        }
      }

      _squaresSub = cardDoc.collection('squares').snapshots().listen(
        (snap) {
          final squares = snap.docs.map(BingoSquare.fromFirestore).toList()..sort((a, b) => a.position.compareTo(b.position));
          state = state.copyWith(
            card: BingoCard(id: cardDoc.id, year: selectedYear, squares: squares),
            loading: false,
            clearError: true,
            availableYears: availableYears,
          );
        },
        onError: (Object e) => state = state.copyWith(loading: false, error: _friendlyError(e)),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
    }
  }

  void toggleEditMode() => state = state.copyWith(editMode: !state.editMode);

  Future<void> toggleSquare(String squareId, bool currentlyCompleted) async {
    if (_uid == null) return;
    if (state.selectedYear != DateTime.now().year) {
      state = state.copyWith(error: "Only this year's card can be edited");
      return;
    }
    try {
      final squareDoc = _cardsCollection.doc('${state.selectedYear}').collection('squares').doc(squareId);
      final data = (await squareDoc.get()).data();
      if (data?['locked'] == true) {
        state = state.copyWith(error: "This square can't be edited");
        return;
      }
      await squareDoc.update({'completed': !currentlyCompleted});
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
    }
  }

  Future<void> renameSquare(String squareId, String label) async {
    if (_uid == null) return;
    if (state.selectedYear != DateTime.now().year) {
      state = state.copyWith(error: "Only this year's card can be edited");
      return;
    }
    try {
      final squareDoc = _cardsCollection.doc('${state.selectedYear}').collection('squares').doc(squareId);
      final data = (await squareDoc.get()).data();
      if (data?['locked'] == true) {
        state = state.copyWith(error: "This square can't be edited");
        return;
      }
      await squareDoc.update({'label': label});
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
    }
  }

  Future<void> reset() async {
    if (_uid == null) return;
    try {
      final cardDoc = _cardsCollection.doc('${DateTime.now().year}');
      final squares = await cardDoc.collection('squares').get();
      final batch = _db.batch();
      for (final doc in squares.docs) {
        if (doc.data()['locked'] != true) batch.update(doc.reference, {'completed': false});
      }
      await batch.commit();
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
    }
  }

  @override
  void dispose() {
    _squaresSub?.cancel();
    super.dispose();
  }
}

final bingoProvider = StateNotifierProvider<BingoNotifier, BingoState>((ref) {
  final notifier = BingoNotifier(ref.watch(firestoreProvider), ref.watch(authProvider).user?.id, ref.read(selectedYearProvider));
  ref.listen<int>(selectedYearProvider, (previous, next) {
    if (previous != next) notifier.load(year: next);
  });
  return notifier;
});
