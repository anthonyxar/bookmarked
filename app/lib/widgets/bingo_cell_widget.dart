import 'package:flutter/material.dart';

import '../theme.dart';

/// Width / height of a cell in the 5-column bingo grids. Portrait rather than
/// square: at ~55dp wide a square cell only fits three or four short lines, so
/// longer labels ("Recommended by a friend") overflowed the border.
const bingoCellAspectRatio = 0.72;

class BingoCellWidget extends StatelessWidget {
  final String label;
  final bool completed;
  final bool locked;
  final bool editMode;
  final double size;
  final VoidCallback? onTap;

  const BingoCellWidget({
    super.key,
    required this.label,
    required this.completed,
    required this.locked,
    required this.editMode,
    this.size = 64,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: completed ? AppColors.green : AppColors.paperSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: editMode ? AppColors.green : (completed ? AppColors.green : AppColors.line),
            width: editMode ? 1.5 : 1,
            style: editMode ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size / 7,
                fontWeight: FontWeight.w600,
                color: completed ? AppColors.paperSoft : AppColors.ink,
              ),
            ),
            if (completed)
              Icon(Icons.check_circle, size: size * 0.62, color: AppColors.paperSoft.withValues(alpha: 0.92)),
          ],
        ),
      ),
    );
  }
}
