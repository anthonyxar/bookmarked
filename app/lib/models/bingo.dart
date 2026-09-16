class BingoSquare {
  final String id;
  final int position;
  final String label;
  final bool completed;
  final bool locked;

  BingoSquare({
    required this.id,
    required this.position,
    required this.label,
    required this.completed,
    required this.locked,
  });

  factory BingoSquare.fromJson(Map<String, dynamic> json) => BingoSquare(
        id: json['id'] as String,
        position: json['position'] as int,
        label: json['label'] as String,
        completed: json['completed'] as bool,
        locked: json['locked'] as bool,
      );
}

class BingoCard {
  final String id;
  final int year;
  final List<BingoSquare> squares;
  final List<int> availableYears;

  BingoCard({required this.id, required this.year, required this.squares, this.availableYears = const []});

  int get completedCount => squares.where((s) => s.completed).length;

  factory BingoCard.fromJson(Map<String, dynamic> json) => BingoCard(
        id: json['id'] as String,
        year: json['year'] as int,
        squares: (json['squares'] as List).map((s) => BingoSquare.fromJson(s as Map<String, dynamic>)).toList(),
        availableYears: (json['available_years'] as List? ?? []).map((y) => y as int).toList(),
      );
}
