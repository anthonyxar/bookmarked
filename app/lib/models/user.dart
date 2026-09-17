import 'package:cloud_firestore/cloud_firestore.dart';

/// Profile data from `users/{uid}`. Identity/credentials (email, password)
/// live in Firebase Auth, not here — see docs/adr/0001-migrate-postgres-fastapi-to-firebase.md.
class AppUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final int readingGoal;
  final List<String> genres;

  AppUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.readingGoal,
    required this.genres,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      id: doc.id,
      name: data['name'] as String? ?? 'Reader',
      avatarUrl: data['avatarUrl'] as String?,
      readingGoal: data['readingGoal'] as int? ?? 40,
      genres: (data['genres'] as List?)?.map((g) => g as String).toList() ?? const [],
    );
  }
}
