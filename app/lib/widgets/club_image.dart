import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme.dart';

class ClubImage extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final double borderRadius;
  const ClubImage({super.key, this.imageUrl, required this.name, this.size = 84, this.borderRadius = 16});

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.isEmpty ? '?' : words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: AppColors.greenSoft,
      alignment: Alignment.center,
      child: Text(_initials, style: TextStyle(color: AppColors.green, fontSize: size * 0.3, fontWeight: FontWeight.w700)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageUrl == null
          ? fallback
          : Image.network(
              resolveMediaUrl(imageUrl!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
