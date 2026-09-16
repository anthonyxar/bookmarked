import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's mark: a bookmark silhouette filled with a tiny shelf of stacked
/// book spines, used next to the "Bookmarked" wordmark and on auth screens.
class AppIcon extends StatelessWidget {
  final double size;
  const AppIcon({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BookmarkShelfPainter()),
    );
  }
}

/// Paints a bookmark silhouette filled with rows of book spines, framed by
/// its own outline instead of sitting on a solid background badge.
class _BookmarkShelfPainter extends CustomPainter {
  static const _spineColors = [
    AppColors.gold,
    AppColors.terra,
    Color(0xFF8E5B8A),
    Color(0xFF4A6B7A),
    Color(0xFF6B6248),
  ];

  // Rows of spines, each as (xStart, width) in a 3..21 unit coordinate
  // space (24-unit design box, matching the bookmark's own width), with an
  // index into _spineColors.
  static const _rows = [
    [
      [3.00, 3.45, 0],
      [6.98, 2.55, 1],
      [10.05, 3.90, 2],
      [14.48, 2.40, 3],
      [17.40, 3.60, 4],
    ],
    [
      [3.00, 4.50, 1],
      [8.10, 3.45, 2],
      [12.15, 4.35, 3],
      [17.10, 3.90, 4],
    ],
    [
      [3.00, 3.00, 2],
      [6.45, 3.75, 4],
      [10.65, 2.70, 0],
      [13.80, 3.45, 1],
      [17.70, 3.30, 3],
    ],
  ];

  static const _rowBands = [
    [2.33, 8.22],
    [9.11, 14.89],
    [15.78, 21.67],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    double dx(double v) => v * s;

    Path bookmarkPath() {
      const x0 = 3.0, x1 = 21.0, y0 = 2.0, bottomY = 22.0, notchY = 17.0, r = 2.2;
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
          topLeft: Radius.circular(dx(0.4)),
          topRight: Radius.circular(dx(0.4)),
        );
        canvas.drawRRect(rect, Paint()..color = _spineColors[spine[2] as int]);
      }
    }

    final shelfPaint = Paint()..color = AppColors.ink.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTRB(0, dx(8.22), size.width, dx(9.11)), shelfPaint);
    canvas.drawRect(Rect.fromLTRB(0, dx(14.89), size.width, dx(15.78)), shelfPaint);

    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dx(1.3)
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.ink.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _BookmarkShelfPainter oldDelegate) => false;
}
