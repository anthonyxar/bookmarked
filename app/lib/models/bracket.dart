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
}

class BracketFavorite {
  final int month;
  final BracketBook? book;

  BracketFavorite({required this.month, this.book});
}

class BracketMatch {
  final String id;
  final String round;
  final BracketBook? bookA;
  final BracketBook? bookB;
  final String? winnerId;

  BracketMatch({required this.id, required this.round, this.bookA, this.bookB, this.winnerId});

  bool get isReady => bookA != null && bookB != null;
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
}
