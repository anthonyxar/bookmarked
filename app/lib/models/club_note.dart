import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory ClubNote.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, {required String authorName}) {
    final data = doc.data()!;
    return ClubNote(
      id: doc.id,
      chapter: data['chapter'] as int,
      body: data['body'] as String,
      userId: data['userId'] as String,
      authorName: authorName,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
