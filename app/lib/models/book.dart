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

  static DateTime? _parseDate(dynamic v) => v == null ? null : DateTime.parse(v as String);

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        series: json['series'] as String?,
        bookNo: json['book_no'] as int?,
        genre: json['genre'] as String?,
        coverColor: json['cover_color'] as String,
        coverUrl: json['cover_url'] as String?,
        published: json['published'] as String?,
        pages: json['pages'] as int?,
        format: json['format'] as String,
        purchased: json['purchased'] as bool,
        read: json['read'] as bool,
        timesRead: json['times_read'] as int,
        startDate: _parseDate(json['start_date']),
        endDate: _parseDate(json['end_date']),
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCover: json['rating_cover'] as int?,
        ratingWriting: json['rating_writing'] as int?,
        ratingPlot: json['rating_plot'] as int?,
        ratingCharacters: json['rating_characters'] as int?,
        enjoyed: json['enjoyed'] as bool?,
        readAgain: json['read_again'] as bool?,
        likedMost: json['liked_most'] as String?,
        likedLeast: json['liked_least'] as String?,
        feel: json['feel'] as String?,
        trope: json['trope'] as String?,
        finalReview: json['final_review'] as String?,
        favoriteCharacters: (json['favorite_characters'] as List).map((e) => e as String).toList(),
        notableScenes: (json['notable_scenes'] as List).map((e) => e as String).toList(),
        quotes: (json['quotes'] as List).map((e) => e as String).toList(),
      );
}
