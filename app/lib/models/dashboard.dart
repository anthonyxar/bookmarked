class GenreCount {
  final String genre;
  final int count;
  GenreCount(this.genre, this.count);
  factory GenreCount.fromJson(Map<String, dynamic> json) => GenreCount(json['genre'] as String, json['count'] as int);
}

class RatingCount {
  final double rating;
  final int count;
  RatingCount(this.rating, this.count);
  factory RatingCount.fromJson(Map<String, dynamic> json) =>
      RatingCount((json['rating'] as num).toDouble(), json['count'] as int);
}

class MonthCount {
  final int month;
  final int count;
  MonthCount(this.month, this.count);
  factory MonthCount.fromJson(Map<String, dynamic> json) => MonthCount(json['month'] as int, json['count'] as int);
}

class Dashboard {
  final int totalRead;
  final double avgRating;
  final int pagesRead;
  final List<GenreCount> byGenre;
  final List<RatingCount> byRating;
  final List<MonthCount> byMonth;

  Dashboard({
    required this.totalRead,
    required this.avgRating,
    required this.pagesRead,
    required this.byGenre,
    required this.byRating,
    required this.byMonth,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        totalRead: json['total_read'] as int,
        avgRating: (json['avg_rating'] as num).toDouble(),
        pagesRead: json['pages_read'] as int,
        byGenre: (json['by_genre'] as List).map((g) => GenreCount.fromJson(g as Map<String, dynamic>)).toList(),
        byRating: (json['by_rating'] as List).map((r) => RatingCount.fromJson(r as Map<String, dynamic>)).toList(),
        byMonth: (json['by_month'] as List).map((m) => MonthCount.fromJson(m as Map<String, dynamic>)).toList(),
      );
}
