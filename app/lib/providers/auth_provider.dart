import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class AuthState {
  final AppUser? user;
  final bool loading;
  final bool initializing;
  final String? error;

  const AuthState({this.user, this.loading = false, this.initializing = true, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({AppUser? user, bool? loading, bool? initializing, String? error, bool clearError = false, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      initializing: initializing ?? this.initializing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  static const _tokenKey = 'bookmarked_token';

  AuthNotifier(this._api) : super(const AuthState()) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) {
      state = state.copyWith(initializing: false);
      return;
    }
    _api.token = token;
    try {
      final json = await _api.get('/auth/me');
      state = state.copyWith(user: AppUser.fromJson(json as Map<String, dynamic>), initializing: false);
    } catch (_) {
      await prefs.remove(_tokenKey);
      _api.token = null;
      state = state.copyWith(initializing: false);
    }
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required int readingGoal,
    required List<String> genres,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final json = await _api.post('/auth/register', body: {
        'email': email,
        'password': password,
        'name': name,
        'reading_goal': readingGoal,
        'genres': genres,
      });
      await _applyToken(json as Map<String, dynamic>);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final json = await _api.post('/auth/login', body: {'email': email, 'password': password});
      await _applyToken(json as Map<String, dynamic>);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    }
  }

  Future<void> _applyToken(Map<String, dynamic> json) async {
    final token = json['access_token'] as String;
    _api.token = token;
    await _persistToken(token);
    state = state.copyWith(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      loading: false,
    );
  }

  Future<void> updateProfile({String? name, int? readingGoal, List<String>? genres}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (readingGoal != null) body['reading_goal'] = readingGoal;
    if (genres != null) body['genres'] = genres;
    final json = await _api.patch('/users/me', body: body);
    state = state.copyWith(user: AppUser.fromJson(json as Map<String, dynamic>));
  }

  Future<bool> uploadAvatar({required List<int> bytes, required String filename, required String contentType}) async {
    try {
      final json = await _api.uploadFile('/users/me/avatar', field: 'file', bytes: bytes, filename: filename, contentType: contentType);
      state = state.copyWith(user: AppUser.fromJson(json as Map<String, dynamic>));
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _api.token = null;
    state = const AuthState(initializing: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(apiClientProvider));
});
