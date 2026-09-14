class AppUser {
  final String id;
  final String email;
  final String name;
  final int readingGoal;
  final List<String> genres;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.readingGoal,
    required this.genres,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        readingGoal: json['reading_goal'] as int,
        genres: (json['genres'] as List).map((g) => g as String).toList(),
      );
}
