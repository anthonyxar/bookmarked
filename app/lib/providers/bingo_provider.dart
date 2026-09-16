import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bingo.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

class BingoState {
  final BingoCard? card;
  final bool loading;
  final bool editMode;
  final String? error;

  const BingoState({this.card, this.loading = false, this.editMode = false, this.error});

  BingoState copyWith({
    BingoCard? card,
    bool? loading,
    bool? editMode,
    String? error,
    bool clearError = false,
  }) =>
      BingoState(
        card: card ?? this.card,
        loading: loading ?? this.loading,
        editMode: editMode ?? this.editMode,
        error: clearError ? null : (error ?? this.error),
      );
}

class BingoNotifier extends StateNotifier<BingoState> {
  final ApiClient _api;
  BingoNotifier(this._api) : super(const BingoState());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final json = await _api.get('/bingo');
      state = state.copyWith(
        card: BingoCard.fromJson(json as Map<String, dynamic>),
        loading: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
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
  return BingoNotifier(ref.watch(apiClientProvider));
});
