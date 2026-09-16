class ClubNote {
  final String id;
  final int chapter;
  final String body;
  final String userId;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClubNote({
    required this.id,
    required this.chapter,
    required this.body,
    required this.userId,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClubNote.fromJson(Map<String, dynamic> json) => ClubNote(
        id: json['id'] as String,
        chapter: json['chapter'] as int,
        body: json['body'] as String,
        userId: json['user_id'] as String,
        authorName: json['author_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
