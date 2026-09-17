import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String? series;
  final int? bookNo;
  final String? genre;
  final String coverColor;
  final String? coverUrl;
  final String? published;
  final int? pages;
  final String format;

  final bool purchased;
  final bool read;
  final int timesRead;
  final DateTime? startDate;
  final DateTime? endDate;

  final double? rating;
  final int? ratingCover;
  final int? ratingWriting;
  final int? ratingPlot;
  final int? ratingCharacters;
  final bool? enjoyed;
  final bool? readAgain;
  final String? likedMost;
  final String? likedLeast;
  final String? feel;
  final String? trope;
  final String? finalReview;
  final List<String> favoriteCharacters;
  final List<String> notableScenes;
  final List<String> quotes;

  Book({
    required this.id,
    required this.title,
    required this.author,
    this.series,
    this.bookNo,
    this.genre,
    required this.coverColor,
    this.coverUrl,
    this.published,
    this.pages,
    required this.format,
    required this.purchased,
    required this.read,
    required this.timesRead,
    this.startDate,
    this.endDate,
    this.rating,
    this.ratingCover,
    this.ratingWriting,
    this.ratingPlot,
    this.ratingCharacters,
    this.enjoyed,
    this.readAgain,
    this.likedMost,
    this.likedLeast,
    this.feel,
    this.trope,
    this.finalReview,
    required this.favoriteCharacters,
    required this.notableScenes,
    required this.quotes,
  });

  String get initials {
    final words = title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.take(3).map((w) => w[0].toUpperCase()).join();
  }

  bool get isReading => purchased && !read && startDate != null;

  static DateTime? _parseDate(dynamic v) => v == null ? null : (v as Timestamp).toDate();
  static List<String> _parseStrings(dynamic v) => (v as List?)?.map((e) => e as String).toList() ?? const [];

  factory Book.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Book(
      id: doc.id,
      title: data['title'] as String? ?? '',
      author: data['author'] as String? ?? '',
      series: data['series'] as String?,
      bookNo: data['bookNo'] as int?,
      genre: data['genre'] as String?,
      coverColor: data['coverColor'] as String? ?? '#3F5D4E',
      coverUrl: data['coverUrl'] as String?,
      published: data['published'] as String?,
      pages: data['pages'] as int?,
      format: data['format'] as String? ?? 'physical',
      purchased: data['purchased'] as bool? ?? false,
      read: data['read'] as bool? ?? false,
      timesRead: data['timesRead'] as int? ?? 0,
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      rating: (data['rating'] as num?)?.toDouble(),
      ratingCover: data['ratingCover'] as int?,
      ratingWriting: data['ratingWriting'] as int?,
      ratingPlot: data['ratingPlot'] as int?,
      ratingCharacters: data['ratingCharacters'] as int?,
      enjoyed: data['enjoyed'] as bool?,
      readAgain: data['readAgain'] as bool?,
      likedMost: data['likedMost'] as String?,
      likedLeast: data['likedLeast'] as String?,
      feel: data['feel'] as String?,
      trope: data['trope'] as String?,
      finalReview: data['finalReview'] as String?,
      favoriteCharacters: _parseStrings(data['favoriteCharacters']),
      notableScenes: _parseStrings(data['notableScenes']),
      quotes: _parseStrings(data['quotes']),
    );
  }
}
