import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory BingoSquare.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return BingoSquare(
      id: doc.id,
      position: data['position'] as int? ?? int.parse(doc.id),
      label: data['label'] as String? ?? '',
      completed: data['completed'] as bool? ?? false,
      locked: data['locked'] as bool? ?? false,
    );
  }
}

class BingoCard {
  final String id;
  final int year;
  final List<BingoSquare> squares;
  final List<int> availableYears;

  BingoCard({required this.id, required this.year, required this.squares, this.availableYears = const []});

  int get completedCount => squares.where((s) => s.completed).length;
}
