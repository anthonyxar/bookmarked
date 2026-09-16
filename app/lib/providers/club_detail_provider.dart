import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club.dart';
import '../models/club_bingo.dart';
import 'auth_provider.dart';

final clubDetailProvider = FutureProvider.family<Club, String>((ref, clubId) async {
  final json = await ref.watch(apiClientProvider).get('/clubs/$clubId');
  return Club.fromJson(json as Map<String, dynamic>);
});

final clubBingoProvider = FutureProvider.family<ClubBingo, String>((ref, clubId) async {
  final json = await ref.watch(apiClientProvider).get('/clubs/$clubId/bingo');
  return ClubBingo.fromJson(json as Map<String, dynamic>);
});
