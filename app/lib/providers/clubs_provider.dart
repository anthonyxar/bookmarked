import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

const _pageSize = 30;

class ClubsState {
  final List<Club> clubs;
  final List<ClubInvite> invites;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int total;

  const ClubsState({
    this.clubs = const [],
    this.invites = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.total = 0,
  });

  bool get hasMore => clubs.length < total;

  ClubsState copyWith({
    List<Club>? clubs,
    List<ClubInvite>? invites,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? total,
  }) {
    return ClubsState(
      clubs: clubs ?? this.clubs,
      invites: invites ?? this.invites,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      total: total ?? this.total,
    );
  }
}

class ClubsNotifier extends StateNotifier<ClubsState> {
  final ApiClient _api;
  ClubsNotifier(this._api) : super(const ClubsState());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final clubsJson = await _api.get('/clubs', query: {'limit': '$_pageSize', 'offset': '0'});
      final invitesJson = await _api.get('/clubs/invites');
      final clubsMap = clubsJson as Map<String, dynamic>;
      state = state.copyWith(
        clubs: (clubsMap['items'] as List).map((c) => Club.fromJson(c as Map<String, dynamic>)).toList(),
        invites: (invitesJson as List).map((i) => ClubInvite.fromJson(i as Map<String, dynamic>)).toList(),
        loading: false,
        total: clubsMap['total'] as int,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final clubsJson = await _api.get('/clubs', query: {'limit': '$_pageSize', 'offset': '${state.clubs.length}'});
      final clubsMap = clubsJson as Map<String, dynamic>;
      final more = (clubsMap['items'] as List).map((c) => Club.fromJson(c as Map<String, dynamic>)).toList();
      state = state.copyWith(clubs: [...state.clubs, ...more], loadingMore: false, total: clubsMap['total'] as int);
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, error: e.message);
    }
  }

  Future<Club?> create(String name, String? description) async {
    try {
      final json = await _api.post('/clubs', body: {'name': name, 'description': description});
      await load();
      return Club.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    }
  }

  Future<bool> respondToInvite(String clubId, bool accept) async {
    try {
      await _api.post('/clubs/$clubId/invites/respond', body: {'accept': accept});
      await load();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  Future<bool> leaveClub(String clubId) async {
    try {
      await _api.post('/clubs/$clubId/leave');
      await load();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  Future<bool> deleteClub(String clubId) async {
    try {
      await _api.delete('/clubs/$clubId');
      await load();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  Future<bool> transferOwnership(String clubId, String newOwnerId) async {
    try {
      await _api.post('/clubs/$clubId/transfer-ownership', body: {'new_owner_id': newOwnerId});
      await load();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }
}

final clubsProvider = StateNotifierProvider<ClubsNotifier, ClubsState>((ref) {
  return ClubsNotifier(ref.watch(apiClientProvider));
});
