import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club.dart';
import '../models/club_bingo.dart';
import 'auth_provider.dart';
import 'clubs_provider.dart';

final clubDetailProvider = FutureProvider.family<Club, String>((ref, clubId) async {
  final db = ref.watch(firestoreProvider);
  final uid = ref.watch(authProvider.select((s) => s.user?.id));
  if (uid == null) throw StateError('Not signed in');
  final myMembership = await db.collection('clubs').doc(clubId).collection('memberships').doc(uid).get();
  final myRole = myMembership.data()?['role'] as String? ?? 'member';
  return fetchClub(db, clubId, myRole);
});

final clubBingoProvider = FutureProvider.family<ClubBingo, String>((ref, clubId) async {
  final db = ref.watch(firestoreProvider);
  final uid = ref.watch(authProvider.select((s) => s.user?.id));
  if (uid == null) throw StateError('Not signed in');
  return fetchOrCreateClubBingo(db, clubId, uid);
});
