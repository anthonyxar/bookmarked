import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's mark: a small badge used next to the "Bookmarked" wordmark.
class AppIcon extends StatelessWidget {
  final double size;
  const AppIcon({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: size * 0.62,
        height: size * 0.62,
        child: CustomPaint(painter: _BookmarkShelfPainter()),
      ),
    );
  }
}

/// Paints a bookmark silhouette (matching the previous `bookmark_rounded`
/// proportions) filled with a tiny shelf of stacked book spines instead of
/// a solid color, plus a thin outline so the bookmark shape stays legible.
class _BookmarkShelfPainter extends CustomPainter {
  static const _spineColors = [
    AppColors.gold,
    AppColors.terra,
    Color(0xFF8E5B8A),
    Color(0xFF4A6B7A),
    Color(0xFF6B6248),
  ];

  // Rows of spines, each as (xStart, width) in a 6..18 unit coordinate
  // space (24-unit design box), with an index into _spineColors.
  static const _rows = [
    [
      [6.0, 2.3, 0],
      [8.65, 1.7, 1],
      [10.7, 2.6, 2],
      [13.65, 1.6, 3],
      [15.6, 2.4, 4],
    ],
    [
      [6.0, 3.0, 1],
      [9.4, 2.3, 2],
      [12.1, 2.9, 3],
      [15.4, 2.6, 4],
    ],
    [
      [6.0, 2.0, 2],
      [8.3, 2.5, 4],
      [11.1, 1.8, 0],
      [13.2, 2.3, 1],
      [15.8, 2.2, 3],
    ],
  ];

  static const _rowBands = [
    [3.3, 8.6],
    [9.4, 14.6],
    [15.4, 20.7],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    double dx(double v) => v * s;

    Path bookmarkPath() {
      const x0 = 6.0, x1 = 18.0, y0 = 3.0, bottomY = 21.0, notchY = 16.5, r = 1.6;
      return Path()
        ..moveTo(dx(x0), dx(y0 + r))
        ..quadraticBezierTo(dx(x0), dx(y0), dx(x0 + r), dx(y0))
        ..lineTo(dx(x1 - r), dx(y0))
        ..quadraticBezierTo(dx(x1), dx(y0), dx(x1), dx(y0 + r))
        ..lineTo(dx(x1), dx(bottomY))
        ..lineTo(dx((x0 + x1) / 2), dx(notchY))
        ..lineTo(dx(x0), dx(bottomY))
        ..close();
    }

    final path = bookmarkPath();

    canvas.save();
    canvas.clipPath(path);

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.paperSoft);

    for (var r = 0; r < _rows.length; r++) {
      final band = _rowBands[r];
      for (final spine in _rows[r]) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTRB(dx(spine[0] as double), dx(band[0]), dx((spine[0] as double) + (spine[1] as double)), dx(band[1])),
          topLeft: Radius.circular(dx(0.35)),
          topRight: Radius.circular(dx(0.35)),
        );
        canvas.drawRRect(rect, Paint()..color = _spineColors[spine[2] as int]);
      }
    }

    final shelfPaint = Paint()..color = AppColors.ink.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTRB(0, dx(8.6), size.width, dx(9.4)), shelfPaint);
    canvas.drawRect(Rect.fromLTRB(0, dx(14.6), size.width, dx(15.4)), shelfPaint);

    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dx(1.0)
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.ink.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _BookmarkShelfPainter oldDelegate) => false;
}
