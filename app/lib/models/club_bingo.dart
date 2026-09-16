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

  factory ClubBingoSquare.fromJson(Map<String, dynamic> json) => ClubBingoSquare(
        id: json['id'] as String,
        position: json['position'] as int,
        label: json['label'] as String,
        completed: json['completed'] as bool,
        locked: json['locked'] as bool,
      );
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

  factory ClubBingoLeaderboardEntry.fromJson(Map<String, dynamic> json) => ClubBingoLeaderboardEntry(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        completedCount: json['completed_count'] as int,
        totalCount: json['total_count'] as int,
        wonAt: json['won_at'] != null ? DateTime.parse(json['won_at'] as String) : null,
      );
}

class ClubBingo {
  final List<ClubBingoSquare> squares;
  final List<ClubBingoLeaderboardEntry> leaderboard;

  ClubBingo({required this.squares, required this.leaderboard});

  int get completedCount => squares.where((s) => s.completed).length;

  factory ClubBingo.fromJson(Map<String, dynamic> json) => ClubBingo(
        squares: (json['squares'] as List).map((s) => ClubBingoSquare.fromJson(s as Map<String, dynamic>)).toList(),
        leaderboard: (json['leaderboard'] as List)
            .map((e) => ClubBingoLeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
