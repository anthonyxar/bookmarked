class ClubReviewEntry {
  final String userId;
  final String name;
  final String? avatarUrl;
  final bool finished;
  final bool locked;
  final String? spoilerWarning;
  final String? bookId;

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

  ClubReviewEntry({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.finished,
    required this.locked,
    this.spoilerWarning,
    this.bookId,
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
    this.favoriteCharacters = const [],
    this.notableScenes = const [],
    this.quotes = const [],
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory ClubReviewEntry.fromJson(Map<String, dynamic> json) => ClubReviewEntry(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        finished: json['finished'] as bool,
        locked: json['locked'] as bool,
        spoilerWarning: json['spoiler_warning'] as String?,
        bookId: json['book_id'] as String?,
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
        favoriteCharacters: (json['favorite_characters'] as List?)?.map((c) => c as String).toList() ?? const [],
        notableScenes: (json['notable_scenes'] as List?)?.map((s) => s as String).toList() ?? const [],
        quotes: (json['quotes'] as List?)?.map((q) => q as String).toList() ?? const [],
      );
}
