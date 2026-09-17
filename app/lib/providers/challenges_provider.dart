import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../models/challenge.dart';
import '../widgets/genre_chip.dart';
import 'books_provider.dart';
import 'year_provider.dart';

const _azLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

List<bool> _azProgress(Iterable<String> titles) {
  final leads = <String>{};
  for (final title in titles) {
    final stripped = title.trim();
    if (stripped.isEmpty) continue;
    final first = stripped[0].toUpperCase();
    if (_azLetters.contains(first)) leads.add(first);
  }
  return [for (final letter in _azLetters.split('')) leads.contains(letter)];
}

/// Computed client-side from the user's own books, mirroring the retired
/// backend's per-request computation exactly — see the ADR for why this
/// doesn't need a Cloud Function.
final challengesProvider = Provider.autoDispose<AsyncValue<Challenges>>((ref) {
  final booksAsync = ref.watch(userBooksProvider);
  final year = ref.watch(selectedYearProvider);

  return booksAsync.whenData((allBooks) {
    bool readInYear(Book b) => b.read && b.endDate != null && b.endDate!.year == year;
    final readBooks = allBooks.where(readInYear).toList();

    final letters = _azProgress(readBooks.map((b) => b.title));
    final genresHit = readBooks.map((b) => b.genre).whereType<String>().where(genreOptions.contains).toSet();
    final chunkyCount = readBooks.where((b) => (b.pages ?? 0) > 500).length;
    final fiveStarCount = readBooks.where((b) => b.rating == 5.0).length;

    final challenges = [
      Challenge(
        id: 'az_titles',
        title: 'A–Z Titles',
        description: 'Read a book whose title starts with every letter of the alphabet.',
        progress: letters.where((l) => l).length,
        goal: 26,
        letters: letters,
      ),
      Challenge(
        id: 'genre_explorer',
        title: 'Genre Explorer',
        description: 'Read at least one book in every genre.',
        progress: genresHit.length,
        goal: genreOptions.length,
      ),
      Challenge(
        id: 'chunky_reads',
        title: 'Chunky Reads',
        description: 'Finish five books over 500 pages.',
        progress: chunkyCount.clamp(0, 5),
        goal: 5,
      ),
      Challenge(
        id: 'five_star_shelf',
        title: 'Five-Star Shelf',
        description: 'Rate ten books the full five stars.',
        progress: fiveStarCount.clamp(0, 10),
        goal: 10,
      ),
    ];

    return Challenges(year: year, challenges: challenges);
  });
});
