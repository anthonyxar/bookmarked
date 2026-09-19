import 'package:cloud_firestore/cloud_firestore.dart';

/// One of a user's five favourite books. A snapshot of the book's display
/// fields rather than a reference: the user's own `books` docs are private to
/// them, and the profile should still render if a book is later deleted.
class TopBook {
  final String bookId;
  final String title;
  final String author;
  final String coverColor;
  final String? coverUrl;

  const TopBook({
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverColor,
    this.coverUrl,
  });

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'title': title,
        'author': author,
        'coverColor': coverColor,
        'coverUrl': coverUrl,
      };

  factory TopBook.fromMap(Map<String, dynamic> map) => TopBook(
        bookId: map['bookId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        author: map['author'] as String? ?? '',
        coverColor: map['coverColor'] as String? ?? '#6B6248',
        coverUrl: map['coverUrl'] as String?,
      );
}

/// Profile data from `users/{uid}`. Identity/credentials (email, password)
/// live in Firebase Auth, not here — see docs/adr/0001-migrate-postgres-fastapi-to-firebase.md.
class AppUser {
  /// How many favourites a profile can show.
  static const maxTopBooks = 5;

  /// Goal used when nothing has been set yet and there is nothing to base a
  /// suggestion on.
  static const defaultGoal = 40;

  final String id;
  final String name;
  final String? avatarUrl;

  /// Yearly reading goals, keyed by year. Stored as `readingGoals: {"2026": 40}`.
  final Map<int, int> readingGoals;

  /// The single `readingGoal` older accounts were created with. Only ever
  /// stood in for the *current* year's goal — see [goalFor]. New accounts
  /// don't have one.
  final int? legacyGoal;

  final List<String> genres;
  final List<TopBook> topBooks;

  AppUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.readingGoals = const {},
    this.legacyGoal,
    required this.genres,
    this.topBooks = const [],
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  /// The goal for [year], or null if none has been set. An account made
  /// before per-year goals keeps its old single goal for the current year
  /// only, so past years never get judged against today's target.
  int? goalFor(int year, {DateTime? now}) {
    final explicit = readingGoals[year];
    if (explicit != null) return explicit;
    final currentYear = (now ?? DateTime.now()).year;
    return year == currentYear ? legacyGoal : null;
  }

  /// A starting point for a year with no goal: the most recent earlier year's
  /// goal, else the legacy goal, else [defaultGoal].
  int suggestedGoalFor(int year) {
    final earlier = readingGoals.keys.where((y) => y < year).toList()..sort();
    if (earlier.isNotEmpty) return readingGoals[earlier.last]!;
    return legacyGoal ?? defaultGoal;
  }

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};

    final goals = <int, int>{};
    for (final entry in ((data['readingGoals'] as Map?) ?? const {}).entries) {
      final year = int.tryParse('${entry.key}');
      final goal = entry.value;
      if (year != null && goal is num) goals[year] = goal.toInt();
    }

    return AppUser(
      id: doc.id,
      name: data['name'] as String? ?? 'Reader',
      avatarUrl: data['avatarUrl'] as String?,
      readingGoals: goals,
      legacyGoal: (data['readingGoal'] as num?)?.toInt(),
      genres: (data['genres'] as List?)?.map((g) => g as String).toList() ?? const [],
      topBooks: ((data['topBooks'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => TopBook.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}
