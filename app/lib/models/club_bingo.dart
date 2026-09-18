import 'package:cloud_firestore/cloud_firestore.dart';

class ClubBingoSquare {
  final String id;
  final int position;
  final String label;
  final bool completed;
  final bool locked;

  ClubBingoSquare({
    required this.id,
    required this.position,
    required this.label,
    required this.completed,
    required this.locked,
  });

  factory ClubBingoSquare.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ClubBingoSquare(
      id: doc.id,
      position: data['position'] as int? ?? int.parse(doc.id),
      label: data['label'] as String? ?? '',
      completed: data['completed'] as bool? ?? false,
      locked: data['locked'] as bool? ?? false,
    );
  }
}

class ClubBingoLeaderboardEntry {
  final String userId;
  final String name;
  final int completedCount;
  final int totalCount;
  final DateTime? wonAt;

  ClubBingoLeaderboardEntry({
    required this.userId,
    required this.name,
    required this.completedCount,
    required this.totalCount,
    this.wonAt,
  });
}

class ClubBingo {
  final List<ClubBingoSquare> squares;
  final List<ClubBingoLeaderboardEntry> leaderboard;

  ClubBingo({required this.squares, required this.leaderboard});

  int get completedCount => squares.where((s) => s.completed).length;
}
