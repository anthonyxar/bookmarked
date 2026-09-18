import 'package:cloud_firestore/cloud_firestore.dart';

class ClubMember {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String role;
  final String status;
  final int? currentChapter;
  final bool? finished;

  ClubMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.status,
    this.currentChapter,
    this.finished,
  });

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get canManage => isOwner || isAdmin;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class ClubBook {
  final String id;
  final String title;
  final String author;
  final int? totalChapters;
  final String coverColor;
  final String? coverUrl;
  final bool isCurrent;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime pickedAt;

  ClubBook({
    required this.id,
    required this.title,
    required this.author,
    this.totalChapters,
    required this.coverColor,
    this.coverUrl,
    required this.isCurrent,
    this.startDate,
    this.endDate,
    required this.pickedAt,
  });

  factory ClubBook.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ClubBook(
      id: doc.id,
      title: data['title'] as String,
      author: data['author'] as String,
      totalChapters: data['totalChapters'] as int?,
      coverColor: data['coverColor'] as String? ?? '#3F5D4E',
      coverUrl: data['coverUrl'] as String?,
      isCurrent: data['isCurrent'] as bool? ?? false,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      pickedAt: (data['pickedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Club {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String ownerId;
  final String myRole;
  final DateTime createdAt;
  final List<ClubMember> members;
  final ClubBook? currentBook;

  Club({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.ownerId,
    required this.myRole,
    required this.createdAt,
    required this.members,
    this.currentBook,
  });

  bool get canManage => myRole == 'owner' || myRole == 'admin';
  List<ClubMember> get activeMembers => members.where((m) => m.status == 'active').toList();
  ClubMember? memberById(String userId) {
    for (final member in members) {
      if (member.userId == userId) return member;
    }
    return null;
  }
}

class ClubInvite {
  final String clubId;
  final String clubName;
  final String invitedByName;
  final DateTime invitedAt;

  ClubInvite({
    required this.clubId,
    required this.clubName,
    required this.invitedByName,
    required this.invitedAt,
  });
}
