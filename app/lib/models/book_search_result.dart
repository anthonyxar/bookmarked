class BookSearchResult {
  final String title;
  final String author;
  final String? coverUrl;
  final int? pages;
  final String? published;
  final String? genre;

  BookSearchResult({
    required this.title,
    required this.author,
    this.coverUrl,
    this.pages,
    this.published,
    this.genre,
  });

  factory BookSearchResult.fromJson(Map<String, dynamic> json) => BookSearchResult(
        title: json['title'] as String,
        author: json['author'] as String,
        coverUrl: json['cover_url'] as String?,
        pages: json['pages'] as int?,
        published: json['published'] as String?,
        genre: json['genre'] as String?,
      );
}
