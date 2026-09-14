import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

class BooksState {
  final List<Book> books;
  final String filter;
  final bool loading;
  final String? error;

  const BooksState({this.books = const [], this.filter = 'all', this.loading = false, this.error});

  BooksState copyWith({List<Book>? books, String? filter, bool? loading, String? error, bool clearError = false}) {
    return BooksState(
      books: books ?? this.books,
      filter: filter ?? this.filter,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BooksNotifier extends StateNotifier<BooksState> {
  final ApiClient _api;
  BooksNotifier(this._api) : super(const BooksState());

  Future<void> load({String? filter}) async {
    final f = filter ?? state.filter;
    state = state.copyWith(loading: true, filter: f, clearError: true);
    try {
      final json = await _api.get('/books', query: {'filter': f});
      final books = (json as List).map((b) => Book.fromJson(b as Map<String, dynamic>)).toList();
      state = state.copyWith(books: books, loading: false);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<Book?> create(Map<String, dynamic> payload) async {
    try {
      final json = await _api.post('/books', body: payload);
      await load();
      return Book.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    }
  }

  Future<Book?> update(String id, Map<String, dynamic> payload) async {
    try {
      final json = await _api.patch('/books/$id', body: payload);
      await load();
      return Book.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    }
  }

  Future<void> toggleFlag(String id, String field, bool value) => update(id, {field: value});
}

final booksProvider = StateNotifierProvider<BooksNotifier, BooksState>((ref) {
  return BooksNotifier(ref.watch(apiClientProvider));
});
