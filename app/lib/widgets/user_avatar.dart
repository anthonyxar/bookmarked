import 'package:flutter/material.dart';

import '../theme.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double size;
  const UserAvatar({super.key, this.avatarUrl, required this.initials, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: Colors.white, fontSize: size * 0.32, fontWeight: FontWeight.w700)),
    );

    if (avatarUrl == null) return fallback;

    return ClipOval(
      child: Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
