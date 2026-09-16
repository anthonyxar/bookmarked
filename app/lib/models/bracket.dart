class BracketBook {
  final String id;
  final String title;
  final String author;
  final String coverColor;
  final String? coverUrl;
  final double? rating;
  final int? month;

  BracketBook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverColor,
    this.coverUrl,
    this.rating,
    this.month,
  });

  factory BracketBook.fromJson(Map<String, dynamic> json) => BracketBook(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        coverColor: json['cover_color'] as String,
        coverUrl: json['cover_url'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        month: json['month'] as int?,
      );
}

class BracketFavorite {
  final int month;
  final BracketBook? book;

  BracketFavorite({required this.month, this.book});

  factory BracketFavorite.fromJson(Map<String, dynamic> json) => BracketFavorite(
        month: json['month'] as int,
        book: json['book'] != null ? BracketBook.fromJson(json['book'] as Map<String, dynamic>) : null,
      );
}

class BracketMatch {
  final String id;
  final String round;
  final BracketBook? bookA;
  final BracketBook? bookB;
  final String? winnerId;

  BracketMatch({required this.id, required this.round, this.bookA, this.bookB, this.winnerId});

  bool get isReady => bookA != null && bookB != null;

  factory BracketMatch.fromJson(Map<String, dynamic> json) => BracketMatch(
        id: json['id'] as String,
        round: json['round'] as String,
        bookA: json['book_a'] != null ? BracketBook.fromJson(json['book_a'] as Map<String, dynamic>) : null,
        bookB: json['book_b'] != null ? BracketBook.fromJson(json['book_b'] as Map<String, dynamic>) : null,
        winnerId: json['winner_id'] as String?,
      );
}

class BracketData {
  final int year;
  final int monthsSet;
  final List<BracketFavorite> favorites;
  final List<BracketMatch>? matches;
  final BracketBook? champion;

  BracketData({
    required this.year,
    required this.monthsSet,
    required this.favorites,
    this.matches,
    this.champion,
  });

  bool get isComplete => monthsSet == 12;

  BracketMatch? matchById(String id) {
    if (matches == null) return null;
    for (final m in matches!) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<BracketMatch> byRound(String round) => (matches ?? []).where((m) => m.round == round).toList();

  factory BracketData.fromJson(Map<String, dynamic> json) => BracketData(
        year: json['year'] as int,
        monthsSet: json['months_set'] as int,
        favorites: (json['favorites'] as List).map((f) => BracketFavorite.fromJson(f as Map<String, dynamic>)).toList(),
        matches: (json['matches'] as List?)?.map((m) => BracketMatch.fromJson(m as Map<String, dynamic>)).toList(),
        champion: json['champion'] != null ? BracketBook.fromJson(json['champion'] as Map<String, dynamic>) : null,
      );
}
