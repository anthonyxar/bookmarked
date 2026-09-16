import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

const _pageSize = 50;

class BooksState {
  final List<Book> books;
  final String filter;
  final String query;
  final String sort;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int total;

  const BooksState({
    this.books = const [],
    this.filter = 'all',
    this.query = '',
    this.sort = 'title',
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.total = 0,
  });

  bool get hasMore => books.length < total;

  BooksState copyWith({
    List<Book>? books,
    String? filter,
    String? query,
    String? sort,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? total,
  }) {
    return BooksState(
      books: books ?? this.books,
      filter: filter ?? this.filter,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      total: total ?? this.total,
    );
  }
}

class BooksNotifier extends StateNotifier<BooksState> {
  final ApiClient _api;
  BooksNotifier(this._api) : super(const BooksState());

  Future<void> load({String? filter, String? query, String? sort}) async {
    final f = filter ?? state.filter;
    final q = query ?? state.query;
    final s = sort ?? state.sort;
    state = state.copyWith(loading: true, filter: f, query: q, sort: s, clearError: true);
    try {
      final json = await _api.get('/books', query: {
        'filter': f,
        'sort': s,
        if (q.isNotEmpty) 'q': q,
        'limit': '$_pageSize',
        'offset': '0',
      });
      final map = json as Map<String, dynamic>;
      final books = (map['items'] as List).map((b) => Book.fromJson(b as Map<String, dynamic>)).toList();
      state = state.copyWith(books: books, loading: false, total: map['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final json = await _api.get('/books', query: {
        'filter': state.filter,
        'sort': state.sort,
        if (state.query.isNotEmpty) 'q': state.query,
        'limit': '$_pageSize',
        'offset': '${state.books.length}',
      });
      final map = json as Map<String, dynamic>;
      final more = (map['items'] as List).map((b) => Book.fromJson(b as Map<String, dynamic>)).toList();
      state = state.copyWith(books: [...state.books, ...more], loadingMore: false, total: map['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, error: e.message);
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

  Future<bool> delete(String id) async {
    try {
      await _api.delete('/books/$id');
      state = state.copyWith(books: state.books.where((b) => b.id != id).toList(), total: state.total - 1);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }
}

final booksProvider = StateNotifierProvider<BooksNotifier, BooksState>((ref) {
  return BooksNotifier(ref.watch(apiClientProvider));
});
