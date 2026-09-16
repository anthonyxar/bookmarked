class ClubMember {
  final String userId;
  final String name;
  final String email;
  final String? avatarUrl;
  final String role;
  final String status;
  final int? currentChapter;
  final bool? finished;

  ClubMember({
    required this.userId,
    required this.name,
    required this.email,
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

  factory ClubMember.fromJson(Map<String, dynamic> json) => ClubMember(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        role: json['role'] as String,
        status: json['status'] as String,
        currentChapter: json['current_chapter'] as int?,
        finished: json['finished'] as bool?,
      );
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

  static DateTime? _parseDate(dynamic v) => v == null ? null : DateTime.parse(v as String);

  factory ClubBook.fromJson(Map<String, dynamic> json) => ClubBook(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        totalChapters: json['total_chapters'] as int?,
        coverColor: json['cover_color'] as String,
        coverUrl: json['cover_url'] as String?,
        isCurrent: json['is_current'] as bool,
        startDate: _parseDate(json['start_date']),
        endDate: _parseDate(json['end_date']),
        pickedAt: DateTime.parse(json['picked_at'] as String),
      );
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

  factory Club.fromJson(Map<String, dynamic> json) => Club(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        ownerId: json['owner_id'] as String,
        myRole: json['my_role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        members: (json['members'] as List).map((m) => ClubMember.fromJson(m as Map<String, dynamic>)).toList(),
        currentBook: json['current_book'] != null ? ClubBook.fromJson(json['current_book'] as Map<String, dynamic>) : null,
      );
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

  factory ClubInvite.fromJson(Map<String, dynamic> json) => ClubInvite(
        clubId: json['club_id'] as String,
        clubName: json['club_name'] as String,
        invitedByName: json['invited_by_name'] as String,
        invitedAt: DateTime.parse(json['invited_at'] as String),
      );
}
