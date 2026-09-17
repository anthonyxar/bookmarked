import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book_search_result.dart';
import '../widgets/genre_chip.dart';

const _googleBooksUrl = 'https://www.googleapis.com/books/v1/volumes';
const _openLibraryUrl = 'https://openlibrary.org/search.json';

String? _guessGenre(List<String> categories) {
  final joined = categories.join(' ').toLowerCase();
  for (final option in genreOptions) {
    if (joined.contains(option.toLowerCase())) return option;
  }
  return null;
}

/// Looks up book metadata against Google Books, falling back to Open Library
/// (keyless, unlimited) if Google fails or comes back empty. Both are public,
/// keyless APIs, so this runs straight from the client — the old backend
/// proxied it for no real reason (see docs/adr/0001-migrate-postgres-fastapi-to-firebase.md).
Future<List<BookSearchResult>> searchBooks(String query) async {
  try {
    final results = await _searchGoogleBooks(query);
    if (results.isNotEmpty) return results;
  } catch (_) {
    // fall through to Open Library
  }
  try {
    return await _searchOpenLibrary(query);
  } catch (_) {
    return const [];
  }
}

Future<List<BookSearchResult>> _searchGoogleBooks(String query) async {
  final uri = Uri.parse(_googleBooksUrl).replace(queryParameters: {
    'q': query,
    'maxResults': '10',
    'printType': 'books',
  });
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) throw Exception('Google Books request failed (${res.statusCode})');
  final payload = jsonDecode(res.body) as Map<String, dynamic>;
  final items = (payload['items'] as List?) ?? const [];

  final results = <BookSearchResult>[];
  for (final item in items) {
    final info = (item as Map<String, dynamic>)['volumeInfo'] as Map<String, dynamic>? ?? const {};
    final title = info['title'] as String?;
    if (title == null) continue;

    final authors = (info['authors'] as List?)?.cast<String>() ?? const [];
    final imageLinks = info['imageLinks'] as Map<String, dynamic>? ?? const {};
    var coverUrl = imageLinks['thumbnail'] as String? ?? imageLinks['smallThumbnail'] as String?;
    coverUrl = coverUrl?.replaceFirst('http://', 'https://');

    results.add(BookSearchResult(
      title: title,
      author: authors.isNotEmpty ? authors.join(', ') : 'Unknown author',
      coverUrl: coverUrl,
      pages: info['pageCount'] as int?,
      published: info['publishedDate'] as String?,
      genre: _guessGenre((info['categories'] as List?)?.cast<String>() ?? const []),
    ));
  }
  return results;
}

Future<List<BookSearchResult>> _searchOpenLibrary(String query) async {
  final uri = Uri.parse(_openLibraryUrl).replace(queryParameters: {
    'q': query,
    'limit': '10',
    'fields': 'title,author_name,first_publish_year,number_of_pages_median,cover_i,subject',
  });
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) throw Exception('Open Library request failed (${res.statusCode})');
  final payload = jsonDecode(res.body) as Map<String, dynamic>;
  final docs = (payload['docs'] as List?) ?? const [];

  final results = <BookSearchResult>[];
  for (final doc in docs) {
    final d = doc as Map<String, dynamic>;
    final title = d['title'] as String?;
    if (title == null) continue;

    final authors = (d['author_name'] as List?)?.cast<String>() ?? const [];
    final coverId = d['cover_i'] as int?;
    final year = d['first_publish_year'] as int?;

    results.add(BookSearchResult(
      title: title,
      author: authors.isNotEmpty ? authors.join(', ') : 'Unknown author',
      coverUrl: coverId != null ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg' : null,
      pages: d['number_of_pages_median'] as int?,
      published: year?.toString(),
      genre: _guessGenre((d['subject'] as List?)?.cast<String>() ?? const []),
    ));
  }
  return results;
}
