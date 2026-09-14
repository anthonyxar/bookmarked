import 'package:flutter/material.dart';

import '../theme.dart';

class StarRating extends StatelessWidget {
  final int rating;
  final int max;
  final double size;
  final Color color;
  final bool editable;
  final ValueChanged<int>? onRate;

  const StarRating({
    super.key,
    required this.rating,
    this.max = 5,
    this.size = 18,
    this.color = AppColors.gold,
    this.editable = false,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < rating;
        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: filled ? color : AppColors.lineStrong,
        );
        if (!editable) return star;
        return GestureDetector(onTap: () => onRate?.call(i + 1), child: star);
      }),
    );
  }
}
