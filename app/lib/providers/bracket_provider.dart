import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bracket.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

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
  final ApiClient _api;
  BracketNotifier(this._api) : super(BracketState(selectedYear: DateTime.now().year));

  Future<void> load({int? year}) async {
    final selectedYear = year ?? state.selectedYear;
    state = state.copyWith(loading: true, clearError: true, selectedYear: selectedYear);
    try {
      final json = await _api.get('/bracket/$selectedYear');
      state = state.copyWith(bracket: BracketData.fromJson(json as Map<String, dynamic>), loading: false, clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> setFavorite(int month, String bookId) async {
    try {
      final json = await _api.put('/bracket/${state.selectedYear}/favorites/$month', body: {'book_id': bookId});
      state = state.copyWith(bracket: BracketData.fromJson(json as Map<String, dynamic>), clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> clearFavorite(int month) async {
    try {
      await _api.delete('/bracket/${state.selectedYear}/favorites/$month');
      await load();
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> setMatchWinner(String matchId, String bookId) async {
    try {
      final json = await _api.post('/bracket/${state.selectedYear}/matches/$matchId', body: {'book_id': bookId});
      state = state.copyWith(bracket: BracketData.fromJson(json as Map<String, dynamic>), clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }
}

final bracketProvider = StateNotifierProvider<BracketNotifier, BracketState>((ref) {
  return BracketNotifier(ref.watch(apiClientProvider));
});
