import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../models/dashboard.dart';
import 'books_provider.dart';
import 'year_provider.dart';

/// Computed client-side from the user's own books — small enough per-user
/// that there's no need for Firestore aggregation queries or a Cloud
/// Function, just a plain pass over the already-live [userBooksProvider] list.
final dashboardProvider = Provider.autoDispose<AsyncValue<Dashboard>>((ref) {
  final booksAsync = ref.watch(userBooksProvider);
  final year = ref.watch(selectedYearProvider);

  return booksAsync.whenData((allBooks) {
    final currentYear = DateTime.now().year;

    bool readInYear(Book b) => b.read && b.endDate != null && b.endDate!.year == year;
    final readBooks = allBooks.where(readInYear).toList();

    final totalRead = readBooks.length;

    final ratings = readBooks.map((b) => b.rating).whereType<double>().toList();
    final avgRating = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;

    final pagesRead = readBooks.fold<int>(0, (sum, b) => sum + (b.pages ?? 0));

    final genreCounts = <String, int>{};
    for (final b in readBooks) {
      final genre = b.genre;
      if (genre != null) genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }
    final byGenre = genreCounts.entries.map((e) => GenreCount(e.key, e.value)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final ratingCounts = <double, int>{};
    for (final b in readBooks) {
      final rating = b.rating;
      if (rating != null) ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
    }
    final byRating = ratingCounts.entries.map((e) => RatingCount(e.key, e.value)).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));

    final monthCounts = List<int>.filled(12, 0);
    for (final b in readBooks) {
      monthCounts[b.endDate!.month - 1]++;
    }
    final byMonth = [for (var m = 1; m <= 12; m++) MonthCount(m, monthCounts[m - 1])];

    final availableYears = <int>{
      currentYear,
      for (final b in allBooks)
        if (b.read && b.endDate != null) b.endDate!.year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Dashboard(
      year: year,
      availableYears: availableYears,
      totalRead: totalRead,
      avgRating: double.parse(avgRating.toStringAsFixed(1)),
      pagesRead: pagesRead,
      byGenre: byGenre,
      byRating: byRating,
      byMonth: byMonth,
    );
  });
});
