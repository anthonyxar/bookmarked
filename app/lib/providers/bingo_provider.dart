import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bingo.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';
import 'year_provider.dart';

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
  final ApiClient _api;
  BingoNotifier(this._api, int initialYear) : super(BingoState(selectedYear: initialYear));

  Future<void> load({int? year}) async {
    final selectedYear = year ?? state.selectedYear;
    state = state.copyWith(loading: true, clearError: true, clearCard: true, selectedYear: selectedYear, editMode: false);
    try {
      final json = await _api.get('/bingo', query: {'year': '$selectedYear'});
      final card = BingoCard.fromJson(json as Map<String, dynamic>);
      state = state.copyWith(
        card: card,
        loading: false,
        clearError: true,
        availableYears: card.availableYears,
      );
    } on ApiException catch (e) {
      final message = e.statusCode == 404 ? "No bingo card for $selectedYear." : e.message;
      state = state.copyWith(loading: false, error: message);
    }
  }

  void toggleEditMode() => state = state.copyWith(editMode: !state.editMode);

  Future<void> toggleSquare(String squareId, bool currentlyCompleted) async {
    try {
      final json = await _api.patch('/bingo/squares/$squareId', body: {'completed': !currentlyCompleted});
      state = state.copyWith(card: BingoCard.fromJson(json as Map<String, dynamic>), clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> renameSquare(String squareId, String label) async {
    try {
      final json = await _api.patch('/bingo/squares/$squareId', body: {'label': label});
      state = state.copyWith(card: BingoCard.fromJson(json as Map<String, dynamic>), clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> reset() async {
    try {
      final json = await _api.post('/bingo/reset');
      state = state.copyWith(card: BingoCard.fromJson(json as Map<String, dynamic>), clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }
}

final bingoProvider = StateNotifierProvider<BingoNotifier, BingoState>((ref) {
  final notifier = BingoNotifier(ref.watch(apiClientProvider), ref.read(selectedYearProvider));
  ref.listen<int>(selectedYearProvider, (previous, next) {
    if (previous != next) notifier.load(year: next);
  });
  return notifier;
});
