import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// What a report is about. The names are stored in Firestore and must match
/// the `type` values allowed by the `reports` rules (firestore.rules).
enum ReportType { note, review, member, club }

/// Why something is being reported; same rule as [ReportType]: the names must
/// match the `reason` values in the rules.
enum ReportReason {
  spam('Spam'),
  abuse('Abusive or hateful'),
  inappropriate('Inappropriate content'),
  impersonation('Pretending to be someone else'),
  other('Something else');

  final String label;
  const ReportReason(this.label);
}

enum ReportResult { sent, alreadyReported, failed }

/// The uids the signed-in user has blocked (`users/{uid}/blocks`). Blocking
/// hides that person's notes and reviews from you and stops them inviting you
/// to clubs; nothing but the uid is stored (issue #34).
final blockedUserIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.user?.id));
  if (uid == null) return Stream.value(const <String>{});
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('blocks')
      .snapshots()
      .map((snap) => {for (final d in snap.docs) d.id});
});

/// Whether the signed-in user is a moderator (the `admin` custom claim).
/// Read from the cached ID token; after a claim is granted, sign out and in
/// again to pick it up.
final isModeratorProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return false;
  final token = await user.getIdTokenResult();
  return token.claims?['admin'] == true;
});

/// A blocked user's display name, looked up when the blocked list is shown
/// (it isn't copied into the block itself). Null once their account is gone.
final userNameProvider = FutureProvider.autoDispose.family<String?, String>((ref, uid) async {
  final doc = await ref.watch(firestoreProvider).collection('users').doc(uid).get();
  return doc.data()?['name'] as String?;
});

class ModerationService {
  static const maxDetails = 500;
  static const maxSnapshot = 1000;

  final FirebaseFirestore _db;
  final String? _uid;
  ModerationService(this._db, this._uid);

  /// The id the `reports` rules require: one report per (reporter, type,
  /// target), so filing the same report twice is refused.
  static String reportId(String reporterId, ReportType type, String targetId) => '${reporterId}__${type.name}__$targetId';

  static String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);

  /// The document written for a report — every field the rules require, no more.
  static Map<String, dynamic> reportData({
    required String reporterId,
    required ReportType type,
    required String clubId,
    required String targetId,
    String? targetUserId,
    String? bookId,
    required ReportReason reason,
    String details = '',
    String snapshot = '',
  }) =>
      {
        'reporterId': reporterId,
        'type': type.name,
        'targetId': targetId,
        'clubId': clubId,
        'targetUserId': targetUserId,
        'bookId': bookId,
        'reason': reason.name,
        'details': _clip(details.trim(), maxDetails),
        'snapshot': _clip(snapshot.trim(), maxSnapshot),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      };

  Future<void> block(String userId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('blocks').doc(userId).set({'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> unblock(String userId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('blocks').doc(userId).delete();
  }

  /// Files a report. A refusal from the rules means this exact report already
  /// exists (reporters can't read reports, so there's no way to check first).
  Future<ReportResult> report({
    required ReportType type,
    required String clubId,
    required String targetId,
    String? targetUserId,
    String? bookId,
    required ReportReason reason,
    String details = '',
    String snapshot = '',
  }) async {
    final uid = _uid;
    if (uid == null) return ReportResult.failed;
    try {
      await _db.collection('reports').doc(reportId(uid, type, targetId)).set(reportData(
            reporterId: uid,
            type: type,
            clubId: clubId,
            targetId: targetId,
            targetUserId: targetUserId,
            bookId: bookId,
            reason: reason,
            details: details,
            snapshot: snapshot,
          ));
      return ReportResult.sent;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied' ? ReportResult.alreadyReported : ReportResult.failed;
    } catch (_) {
      return ReportResult.failed;
    }
  }
}

final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService(ref.watch(firestoreProvider), ref.watch(authProvider.select((s) => s.user?.id)));
});
