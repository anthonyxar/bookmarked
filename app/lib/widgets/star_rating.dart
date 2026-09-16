import 'package:flutter/material.dart';

import '../theme.dart';

class StarRating extends StatelessWidget {
  final num rating;
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
        final remainder = (rating - i).clamp(0, 1);
        final outline = Icon(Icons.star_border_rounded, size: size, color: AppColors.lineStrong);
        final star = remainder <= 0
            ? outline
            : Stack(
                children: [
                  outline,
                  ClipRect(
                    clipper: _FractionClipper(remainder.toDouble()),
                    child: Icon(Icons.star_rounded, size: size, color: color),
                  ),
                ],
              );
        if (!editable) return star;
        return GestureDetector(onTap: () => onRate?.call(i + 1), child: star);
      }),
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  final double fraction;
  const _FractionClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClipper oldClipper) => oldClipper.fraction != fraction;
}
