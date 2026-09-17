class GenreCount {
  final String genre;
  final int count;
  GenreCount(this.genre, this.count);
}

class RatingCount {
  final double rating;
  final int count;
  RatingCount(this.rating, this.count);
}

class MonthCount {
  final int month;
  final int count;
  MonthCount(this.month, this.count);
}

class Dashboard {
  final int year;
  final List<int> availableYears;
  final int totalRead;
  final double avgRating;
  final int pagesRead;
  final List<GenreCount> byGenre;
  final List<RatingCount> byRating;
  final List<MonthCount> byMonth;

  Dashboard({
    required this.year,
    required this.availableYears,
    required this.totalRead,
    required this.avgRating,
    required this.pagesRead,
    required this.byGenre,
    required this.byRating,
    required this.byMonth,
  });
}
